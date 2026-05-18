using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Contracts.Services;
using Microsoft.Data.Sqlite;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace DingTalkWindowsHost.Automation.StructuredSources;

public sealed class LocalStructuredSourceDiagnosticsProvider : ILocalStructuredSourceDiagnosticsProvider
{
    private static readonly string[] DingTalkRootNames =
    {
        "DingTalk",
        "DingDing",
        "Alibaba\\DingTalk",
        "Alibaba\\DingDing",
    };

    private static readonly byte[] SqliteHeader = Encoding.ASCII.GetBytes("SQLite format 3\0");

    private static readonly byte[] SqliteWalHeader = { 0x37, 0x7f, 0x06, 0x82 };

    private static readonly string[] LevelDbShapeKeywords =
    {
        "message",
        "msg",
        "content",
        "body",
        "text",
        "sender",
        "conversation",
        "chat",
        "timestamp",
        "time",
    };

    private readonly Func<IReadOnlyList<string>> _rootSource;
    private readonly Func<string, string?> _environmentVariableSource;
    private readonly object _changeBaselineGate = new();
    private Dictionary<string, LocalStructuredSourceChangeSnapshot> _changeBaseline = new(StringComparer.Ordinal);

    public LocalStructuredSourceDiagnosticsProvider()
        : this(GetDefaultRoots, Environment.GetEnvironmentVariable)
    {
    }

    public LocalStructuredSourceDiagnosticsProvider(
        Func<IReadOnlyList<string>> rootSource,
        Func<string, string?> environmentVariableSource)
    {
        ArgumentNullException.ThrowIfNull(rootSource);
        ArgumentNullException.ThrowIfNull(environmentVariableSource);

        _rootSource = rootSource;
        _environmentVariableSource = environmentVariableSource;
    }

    public LocalStructuredSourceDiagnosticsResult GetDiagnostics(int candidateLimit)
    {
        var limit = Math.Clamp(candidateLimit, 1, 200);
        var roots = GetExistingDingTalkRoots();
        var candidates = roots
            .SelectMany(EnumerateCandidates)
            .OrderByDescending(static candidate => candidate.LastWriteTime)
            .ThenBy(static candidate => candidate.PathHint, StringComparer.OrdinalIgnoreCase)
            .Take(limit)
            .ToArray();

        var status = roots.Count == 0
            ? StructuredSourceStatus.Unavailable
            : StructuredSourceStatus.NeedsManualApproval;

        return new LocalStructuredSourceDiagnosticsResult(
            ObservedAt: DateTimeOffset.UtcNow,
            Status: status,
            CandidateCount: candidates.Length,
            Recommendation: BuildRecommendation(roots.Count, candidates.Length),
            Candidates: candidates);
    }

    public LocalStructuredSourceChangeDiagnosticsResult GetChangeDiagnostics(
        int candidateLimit,
        bool resetBaseline)
    {
        var limit = Math.Clamp(candidateLimit, 1, 200);
        var roots = GetExistingDingTalkRoots();
        var candidates = roots
            .SelectMany(EnumerateChangeSnapshots)
            .OrderByDescending(static candidate => candidate.LastWriteTime)
            .ThenBy(static candidate => candidate.PathHash, StringComparer.Ordinal)
            .Take(limit)
            .ToArray();
        LocalStructuredSourceChange[] changes;
        lock (_changeBaselineGate)
        {
            var previousBaseline = resetBaseline
                ? new Dictionary<string, LocalStructuredSourceChangeSnapshot>(StringComparer.Ordinal)
                : _changeBaseline;
            changes = candidates
                .Select(candidate => CreateChange(candidate, previousBaseline))
                .Where(change => resetBaseline
                    || change.ChangeKind != LocalStructuredSourceChangeKind.Unchanged)
                .ToArray();
            _changeBaseline = candidates.ToDictionary(
                static candidate => candidate.PathHash,
                static candidate => candidate,
                StringComparer.Ordinal);
        }

        return new LocalStructuredSourceChangeDiagnosticsResult(
            ObservedAt: DateTimeOffset.UtcNow,
            Status: roots.Count == 0
                ? StructuredSourceStatus.Unavailable
                : StructuredSourceStatus.NeedsManualApproval,
            CandidateCount: candidates.Length,
            ChangedCount: changes.Count(static change =>
                change.ChangeKind is LocalStructuredSourceChangeKind.Added
                    or LocalStructuredSourceChangeKind.Modified),
            Recommendation: BuildChangeRecommendation(roots.Count, candidates.Length, changes.Length, resetBaseline),
            Changes: changes);
    }

    public LocalStructuredSourceInspectionDiagnosticsResult GetInspectionDiagnostics(
        int candidateLimit,
        int itemLimit)
    {
        var candidateLimitValue = Math.Clamp(candidateLimit, 1, 100);
        var itemLimitValue = Math.Clamp(itemLimit, 1, 100);
        var candidates = GetInspectionCandidates(candidateLimitValue);
        var inspections = candidates
            .Select(candidate => InspectCandidate(candidate, itemLimitValue))
            .ToArray();
        var inspectedCount = inspections.Count(static inspection =>
            inspection.Status == LocalStructuredSourceInspectionStatus.Inspected);

        return new LocalStructuredSourceInspectionDiagnosticsResult(
            ObservedAt: DateTimeOffset.UtcNow,
            Status: candidates.Count == 0
                ? StructuredSourceStatus.Unavailable
                : StructuredSourceStatus.NeedsManualApproval,
            InspectedCount: inspectedCount,
            Recommendation: BuildInspectionRecommendation(candidates.Count, inspectedCount),
            Inspections: inspections);
    }

    public LocalStructuredContentShapeDiagnosticsResult GetContentShapeDiagnostics(
        int candidateLimit,
        int itemLimit,
        int sampleLimit)
    {
        var candidateLimitValue = Math.Clamp(candidateLimit, 1, 100);
        var itemLimitValue = Math.Clamp(itemLimit, 1, 100);
        var sampleLimitValue = Math.Clamp(sampleLimit, 1, 20);
        var candidates = GetContentShapeCandidates(candidateLimitValue);
        var shapes = candidates
            .Select(candidate => ProbeContentShape(candidate, itemLimitValue, sampleLimitValue))
            .ToArray();
        var actionableCount = shapes.Count(static shape =>
            shape.Status is LocalStructuredContentShapeStatus.Candidate
                or LocalStructuredContentShapeStatus.KeywordOnly);

        return new LocalStructuredContentShapeDiagnosticsResult(
            ObservedAt: DateTimeOffset.UtcNow,
            Status: candidates.Count == 0
                ? StructuredSourceStatus.Unavailable
                : StructuredSourceStatus.NeedsManualApproval,
            ShapeCount: shapes.Length,
            Recommendation: BuildContentShapeRecommendation(candidates.Count, actionableCount),
            Shapes: shapes);
    }

    private IReadOnlyList<string> GetExistingDingTalkRoots()
    {
        return _rootSource()
            .Where(static root => !string.IsNullOrWhiteSpace(root))
            .Select(Path.GetFullPath)
            .SelectMany(CreateDingTalkRootCandidates)
            .Where(Directory.Exists)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static IEnumerable<string> CreateDingTalkRootCandidates(string baseRoot)
    {
        var normalized = Path.GetFileName(baseRoot.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
        if (IsKnownDingTalkRootName(normalized))
        {
            yield return baseRoot;
        }

        foreach (var rootName in DingTalkRootNames)
        {
            yield return Path.Combine(baseRoot, rootName);
        }
    }

    private static bool IsKnownDingTalkRootName(string directoryName)
    {
        return directoryName.Equals("DingTalk", StringComparison.OrdinalIgnoreCase)
            || directoryName.Equals("DingDing", StringComparison.OrdinalIgnoreCase);
    }

    private IEnumerable<LocalStructuredSourceCandidate> EnumerateCandidates(string root)
    {
        foreach (var entry in EnumerateFileSystemEntries(root))
        {
            var candidate = TryCreateCandidate(entry);
            if (candidate is not null)
            {
                yield return candidate;
            }
        }
    }

    private IEnumerable<LocalStructuredSourceChangeSnapshot> EnumerateChangeSnapshots(string root)
    {
        foreach (var entry in EnumerateFileSystemEntries(root))
        {
            var snapshot = TryCreateChangeSnapshot(entry);
            if (snapshot is not null)
            {
                yield return snapshot;
            }
        }
    }

    private IReadOnlyList<LocalStructuredSourceCandidate> GetInspectionCandidates(int candidateLimit)
    {
        return GetExistingDingTalkRoots()
            .SelectMany(EnumerateCandidates)
            .Where(static candidate => candidate.Kind is LocalStructuredSourceCandidateKind.SqliteDatabase
                or LocalStructuredSourceCandidateKind.SqliteWriteAheadLog
                or LocalStructuredSourceCandidateKind.JsonFile
                or LocalStructuredSourceCandidateKind.LevelDbStore
                or LocalStructuredSourceCandidateKind.LogFile
                or LocalStructuredSourceCandidateKind.MediaCache)
            .OrderByDescending(static candidate => candidate.LastWriteTime)
            .ThenBy(static candidate => candidate.PathHint, StringComparer.OrdinalIgnoreCase)
            .Take(candidateLimit)
            .ToArray();
    }

    private IReadOnlyList<LocalStructuredSourceCandidate> GetContentShapeCandidates(int candidateLimit)
    {
        return GetExistingDingTalkRoots()
            .SelectMany(EnumerateCandidates)
            .Where(static candidate => candidate.Kind is LocalStructuredSourceCandidateKind.SqliteDatabase
                or LocalStructuredSourceCandidateKind.SqliteWriteAheadLog
                or LocalStructuredSourceCandidateKind.JsonFile
                or LocalStructuredSourceCandidateKind.LevelDbStore)
            .OrderByDescending(static candidate => candidate.LastWriteTime)
            .ThenBy(static candidate => candidate.PathHint, StringComparer.OrdinalIgnoreCase)
            .Take(candidateLimit)
            .ToArray();
    }

    private LocalStructuredSourceInspection InspectCandidate(
        LocalStructuredSourceCandidate candidate,
        int itemLimit)
    {
        var actualPath = ResolvePathHint(candidate.PathHint);
        if (string.IsNullOrWhiteSpace(actualPath))
        {
            return CreateFailedInspection(candidate, "candidate path could not be resolved");
        }

        try
        {
            return candidate.Kind switch
            {
                LocalStructuredSourceCandidateKind.SqliteDatabase => InspectSqlite(candidate, actualPath, itemLimit),
                LocalStructuredSourceCandidateKind.SqliteWriteAheadLog => CreateSkippedInspection(
                    candidate,
                    "sqlite WAL can contain row frames; schema-only inspection requires the base database"),
                LocalStructuredSourceCandidateKind.JsonFile => InspectJson(candidate, actualPath, itemLimit),
                LocalStructuredSourceCandidateKind.LevelDbStore => InspectLevelDb(candidate, actualPath, itemLimit),
                LocalStructuredSourceCandidateKind.LogFile => CreateSkippedInspection(
                    candidate,
                    "log content may contain messages; schema-only inspection is not available"),
                LocalStructuredSourceCandidateKind.MediaCache => CreateSkippedInspection(
                    candidate,
                    "media content may contain message attachments; binary content was not opened"),
                _ => CreateSkippedInspection(candidate, "candidate kind is not inspectable"),
            };
        }
        catch (SqliteException ex)
        {
            return CreateFailedInspection(candidate, "sqlite schema inspection failed: " + ex.SqliteErrorCode);
        }
        catch (JsonException)
        {
            return CreateFailedInspection(candidate, "json key inspection failed");
        }
        catch (UnauthorizedAccessException)
        {
            return CreateFailedInspection(candidate, "access denied");
        }
        catch (IOException)
        {
            return CreateFailedInspection(candidate, "file system read failed");
        }
        catch (InvalidOperationException)
        {
            return CreateFailedInspection(candidate, "inspection failed");
        }
    }

    private LocalStructuredContentShape ProbeContentShape(
        LocalStructuredSourceCandidate candidate,
        int itemLimit,
        int sampleLimit)
    {
        var actualPath = ResolvePathHint(candidate.PathHint);
        if (string.IsNullOrWhiteSpace(actualPath))
        {
            return CreateContentShape(
                candidate,
                LocalStructuredContentShapeStatus.Failed,
                "candidate path could not be resolved");
        }

        try
        {
            return candidate.Kind switch
            {
                LocalStructuredSourceCandidateKind.SqliteDatabase => ProbeSqliteContentShape(
                    candidate,
                    actualPath,
                    itemLimit,
                    sampleLimit),
                LocalStructuredSourceCandidateKind.SqliteWriteAheadLog => ProbeSqliteWalContentShape(
                    candidate,
                    actualPath),
                LocalStructuredSourceCandidateKind.JsonFile => ProbeJsonContentShape(
                    candidate,
                    actualPath,
                    itemLimit),
                LocalStructuredSourceCandidateKind.LevelDbStore => ProbeLevelDbContentShape(
                    candidate,
                    actualPath,
                    itemLimit),
                _ => CreateContentShape(
                    candidate,
                    LocalStructuredContentShapeStatus.Skipped,
                    "candidate kind is not supported for content-shape probing"),
            };
        }
        catch (SqliteException ex)
        {
            return CreateContentShape(
                candidate,
                LocalStructuredContentShapeStatus.NotReadable,
                "sqlite content shape failed: " + ex.SqliteErrorCode);
        }
        catch (JsonException)
        {
            return CreateContentShape(candidate, LocalStructuredContentShapeStatus.NotReadable, "json shape inspection failed");
        }
        catch (UnauthorizedAccessException)
        {
            return CreateContentShape(candidate, LocalStructuredContentShapeStatus.Failed, "access denied");
        }
        catch (IOException)
        {
            return CreateContentShape(candidate, LocalStructuredContentShapeStatus.Failed, "file system read failed");
        }
        catch (InvalidOperationException)
        {
            return CreateContentShape(candidate, LocalStructuredContentShapeStatus.Failed, "content shape failed");
        }
    }

    private LocalStructuredContentShape ProbeSqliteContentShape(
        LocalStructuredSourceCandidate candidate,
        string path,
        int itemLimit,
        int sampleLimit)
    {
        var pathHash = HashPathHint(candidate.PathHint);
        if (!HasHeader(path, SqliteHeader))
        {
            return CreateContentShape(
                candidate,
                LocalStructuredContentShapeStatus.NotReadable,
                "not a standard SQLite database header; likely encrypted, compressed, or not SQLite");
        }

        LocalStructuredContentShape shape;
        try
        {
            shape = ProbeSqliteContentShapeFromPath(
                candidate,
                pathHash,
                path,
                itemLimit,
                sampleLimit,
                openedSnapshot: false);
        }
        catch (SqliteException ex) when (IsSqliteLockOrIoFailure(ex))
        {
            using var snapshot = TryCreateSqliteSnapshot(path);
            if (snapshot is null)
            {
                throw;
            }

            shape = ProbeSqliteContentShapeFromPath(
                candidate,
                pathHash,
                snapshot.DatabasePath,
                itemLimit,
                sampleLimit,
                openedSnapshot: true);
        }

        return shape;
    }

    private static LocalStructuredContentShape ProbeSqliteContentShapeFromPath(
        LocalStructuredSourceCandidate candidate,
        string pathHash,
        string path,
        int itemLimit,
        int sampleLimit,
        bool openedSnapshot)
    {
        using var connection = OpenReadOnlySqliteConnection(path);
        var tableNames = GetSqliteTables(connection, itemLimit);
        var tableShapes = new List<LocalStructuredContentTableShape>();
        foreach (var tableName in tableNames)
        {
            var columns = GetSqliteColumns(connection, tableName, itemLimit);
            var roleByColumn = columns
                .Select(column => new
                {
                    Name = column,
                    Role = ClassifyColumnRole(column),
                })
                .Where(static column => column.Role != LocalStructuredContentFieldRole.Unknown)
                .ToArray();
            var hasTextRole = roleByColumn.Any(static column =>
                column.Role == LocalStructuredContentFieldRole.Text);
            var hasContextRole = roleByColumn.Any(static column =>
                column.Role is LocalStructuredContentFieldRole.Conversation
                    or LocalStructuredContentFieldRole.Sender
                    or LocalStructuredContentFieldRole.MessageId);
            if (!hasTextRole || !hasContextRole)
            {
                continue;
            }

            var score = roleByColumn.Sum(static column => ScoreRole(column.Role));
            var rowCount = GetSqliteRowCount(connection, tableName);
            var fieldShapes = roleByColumn
                .Select(column => ProbeSqliteFieldShape(
                    connection,
                    tableName,
                    column.Name,
                    column.Role,
                    sampleLimit))
                .ToArray();
            tableShapes.Add(new LocalStructuredContentTableShape(
                Name: SanitizeStructureName(tableName),
                RowCount: rowCount,
                Score: score,
                Evidence: "roleScore=" + score + " rowCount=" + rowCount,
                Fields: fieldShapes));
        }

        var orderedTables = tableShapes
            .OrderByDescending(static table => table.Score)
            .ThenByDescending(static table => table.RowCount)
            .Take(itemLimit)
            .ToArray();
        var sourceDescription = openedSnapshot
            ? "standard SQLite database opened from a temporary snapshot"
            : "standard SQLite database opened";

        return new LocalStructuredContentShape(
            Kind: candidate.Kind,
            Status: orderedTables.Length == 0
                ? LocalStructuredContentShapeStatus.NoMessageShape
                : LocalStructuredContentShapeStatus.Candidate,
            PathHash: pathHash,
            PathHint: candidate.PathHint,
            Evidence: orderedTables.Length == 0
                ? sourceDescription + "; no message-like table shape found"
                : sourceDescription + "; only field names, counts, lengths, and value hashes returned",
            Tables: orderedTables,
            KeywordHits: Array.Empty<LocalStructuredContentKeywordHit>());
    }

    private LocalStructuredContentShape ProbeSqliteWalContentShape(
        LocalStructuredSourceCandidate candidate,
        string path)
    {
        return CreateContentShape(
            candidate,
            HasHeader(path, SqliteWalHeader)
                ? LocalStructuredContentShapeStatus.Skipped
                : LocalStructuredContentShapeStatus.NotReadable,
            HasHeader(path, SqliteWalHeader)
                ? "sqlite WAL header detected; parse through the base database to avoid reading row frames directly"
                : "not a recognized SQLite WAL header");
    }

    private LocalStructuredContentShape ProbeLevelDbContentShape(
        LocalStructuredSourceCandidate candidate,
        string path,
        int itemLimit)
    {
        var hits = CountLevelDbKeywordHits(path, itemLimit);
        return new LocalStructuredContentShape(
            Kind: candidate.Kind,
            Status: hits.Count == 0
                ? LocalStructuredContentShapeStatus.NoMessageShape
                : LocalStructuredContentShapeStatus.KeywordOnly,
            PathHash: HashPathHint(candidate.PathHint),
            PathHint: candidate.PathHint,
            Evidence: hits.Count == 0
                ? "leveldb files were opened read-only; no message-shape keywords found"
                : "leveldb files were opened read-only; only keyword counts returned, key/value payloads were not returned",
            Tables: Array.Empty<LocalStructuredContentTableShape>(),
            KeywordHits: hits);
    }

    private LocalStructuredSourceInspection InspectSqlite(
        LocalStructuredSourceCandidate candidate,
        string path,
        int itemLimit)
    {
        try
        {
            return InspectSqliteFromPath(candidate, path, itemLimit, openedSnapshot: false);
        }
        catch (SqliteException ex) when (IsSqliteLockOrIoFailure(ex))
        {
            using var snapshot = TryCreateSqliteSnapshot(path);
            if (snapshot is null)
            {
                throw;
            }

            return InspectSqliteFromPath(candidate, snapshot.DatabasePath, itemLimit, openedSnapshot: true);
        }
    }

    private static LocalStructuredSourceInspection InspectSqliteFromPath(
        LocalStructuredSourceCandidate candidate,
        string path,
        int itemLimit,
        bool openedSnapshot)
    {
        using var connection = OpenReadOnlySqliteConnection(path);
        var tables = GetSqliteTables(connection, itemLimit);
        var items = new List<LocalStructuredSourceStructureItem>(tables.Count);
        foreach (var tableName in tables)
        {
            var columns = GetSqliteColumns(connection, tableName, itemLimit);
            items.Add(new LocalStructuredSourceStructureItem(
                Kind: LocalStructuredSourceStructureKind.SqliteTable,
                Name: SanitizeStructureName(tableName),
                ChildNames: columns.Select(SanitizeStructureName).ToArray(),
                Evidence: "columnCount=" + columns.Count));
        }

        return new LocalStructuredSourceInspection(
            Kind: candidate.Kind,
            Status: LocalStructuredSourceInspectionStatus.Inspected,
            PathHint: candidate.PathHint,
            Evidence: openedSnapshot
                ? "sqlite schema-only inspection from temporary snapshot; row values not returned"
                : "sqlite schema-only inspection; row values not read",
            StructureItems: items);
    }

    private static SqliteConnection OpenReadOnlySqliteConnection(string path)
    {
        var connectionString = new SqliteConnectionStringBuilder
        {
            DataSource = path,
            Mode = SqliteOpenMode.ReadOnly,
            Cache = SqliteCacheMode.Shared,
            Pooling = false,
            DefaultTimeout = 1,
        }.ToString();

        var connection = new SqliteConnection(connectionString);
        try
        {
            connection.Open();
            return connection;
        }
        catch
        {
            connection.Dispose();
            throw;
        }
    }

    private static bool IsSqliteLockOrIoFailure(SqliteException ex)
    {
        return ex.SqliteErrorCode is 5 or 6 or 10;
    }

    private static SqliteSnapshot? TryCreateSqliteSnapshot(string path)
    {
        var snapshotDirectory = Path.Combine(
            Path.GetTempPath(),
            "dingtalk-sqlite-snapshot-" + Guid.NewGuid().ToString("N"));
        try
        {
            Directory.CreateDirectory(snapshotDirectory);
            var snapshotPath = Path.Combine(snapshotDirectory, Path.GetFileName(path));
            CopyFileShared(path, snapshotPath);
            CopyOptionalFileShared(path + "-wal", snapshotPath + "-wal");
            CopyOptionalFileShared(path + "-shm", snapshotPath + "-shm");
            return new SqliteSnapshot(snapshotDirectory, snapshotPath);
        }
        catch (UnauthorizedAccessException)
        {
            DeleteDirectoryBestEffort(snapshotDirectory);
            return null;
        }
        catch (IOException)
        {
            DeleteDirectoryBestEffort(snapshotDirectory);
            return null;
        }
    }

    private static void CopyOptionalFileShared(string sourcePath, string destinationPath)
    {
        if (!File.Exists(sourcePath))
        {
            return;
        }

        CopyFileShared(sourcePath, destinationPath);
    }

    private static void CopyFileShared(string sourcePath, string destinationPath)
    {
        using var source = File.Open(sourcePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        using var destination = File.Create(destinationPath);
        source.CopyTo(destination);
    }

    private static void DeleteDirectoryBestEffort(string path)
    {
        try
        {
            if (Directory.Exists(path))
            {
                Directory.Delete(path, recursive: true);
            }
        }
        catch (UnauthorizedAccessException)
        {
        }
        catch (IOException)
        {
        }
    }

    private sealed class SqliteSnapshot : IDisposable
    {
        private readonly string _directory;

        public SqliteSnapshot(string directory, string databasePath)
        {
            _directory = directory;
            DatabasePath = databasePath;
        }

        public string DatabasePath { get; }

        public void Dispose()
        {
            DeleteDirectoryBestEffort(_directory);
        }
    }

    private sealed record LocalStructuredSourceChangeSnapshot(
        LocalStructuredSourceCandidateKind Kind,
        string FullPath,
        string PathHash,
        long SizeBytes,
        DateTimeOffset LastWriteTime);

    private static IReadOnlyList<string> GetSqliteTables(SqliteConnection connection, int itemLimit)
    {
        using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT name
            FROM sqlite_schema
            WHERE type = 'table'
              AND name NOT LIKE 'sqlite_%'
            ORDER BY name
            LIMIT $limit
            """;
        command.Parameters.AddWithValue("$limit", itemLimit);

        var tables = new List<string>();
        using var reader = command.ExecuteReader();
        while (reader.Read())
        {
            tables.Add(reader.GetString(0));
        }

        return tables;
    }

    private static IReadOnlyList<string> GetSqliteColumns(
        SqliteConnection connection,
        string tableName,
        int itemLimit)
    {
        using var command = connection.CreateCommand();
        command.CommandText = "PRAGMA table_info(" + QuoteSqliteIdentifier(tableName) + ")";
        var columns = new List<string>();
        using var reader = command.ExecuteReader();
        while (reader.Read() && columns.Count < itemLimit)
        {
            columns.Add(reader.GetString(1));
        }

        return columns;
    }

    private static long GetSqliteRowCount(SqliteConnection connection, string tableName)
    {
        using var command = connection.CreateCommand();
        command.CommandText = "SELECT COUNT(*) FROM " + QuoteSqliteIdentifier(tableName);
        var value = command.ExecuteScalar();
        return Convert.ToInt64(value, System.Globalization.CultureInfo.InvariantCulture);
    }

    private static LocalStructuredContentFieldShape ProbeSqliteFieldShape(
        SqliteConnection connection,
        string tableName,
        string columnName,
        LocalStructuredContentFieldRole role,
        int sampleLimit)
    {
        using var command = connection.CreateCommand();
        command.CommandText = "SELECT "
            + QuoteSqliteIdentifier(columnName)
            + " FROM "
            + QuoteSqliteIdentifier(tableName)
            + " WHERE "
            + QuoteSqliteIdentifier(columnName)
            + " IS NOT NULL LIMIT $limit";
        command.Parameters.AddWithValue("$limit", sampleLimit);

        var sampleCount = 0;
        var minLength = int.MaxValue;
        var maxLength = 0;
        var hashes = new List<string>();
        using var reader = command.ExecuteReader();
        while (reader.Read())
        {
            var value = reader.GetValue(0)?.ToString() ?? string.Empty;
            if (string.IsNullOrWhiteSpace(value))
            {
                continue;
            }

            sampleCount++;
            minLength = Math.Min(minLength, value.Length);
            maxLength = Math.Max(maxLength, value.Length);
            hashes.Add(Sha256Hex(value));
        }

        return new LocalStructuredContentFieldShape(
            Name: SanitizeStructureName(columnName),
            Role: role,
            NonEmptySampleCount: sampleCount,
            MinLength: sampleCount == 0 ? 0 : minLength,
            MaxLength: maxLength,
            SampleValueHashes: hashes);
    }

    private LocalStructuredSourceInspection InspectJson(
        LocalStructuredSourceCandidate candidate,
        string path,
        int itemLimit)
    {
        using var stream = File.OpenRead(path);
        using var document = JsonDocument.Parse(stream);
        var items = new List<LocalStructuredSourceStructureItem>();
        CollectJsonStructure(document.RootElement, "$", items, itemLimit);

        return new LocalStructuredSourceInspection(
            Kind: candidate.Kind,
            Status: LocalStructuredSourceInspectionStatus.Inspected,
            PathHint: candidate.PathHint,
            Evidence: "json key-only inspection; scalar values not returned",
            StructureItems: items);
    }

    private LocalStructuredContentShape ProbeJsonContentShape(
        LocalStructuredSourceCandidate candidate,
        string path,
        int itemLimit)
    {
        using var stream = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        using var document = JsonDocument.Parse(stream);
        var tables = new List<LocalStructuredContentTableShape>();
        CollectJsonContentShapes(document.RootElement, "$", tables, itemLimit);
        var orderedTables = tables
            .GroupBy(static table => table.Name, StringComparer.Ordinal)
            .Select(static group => group
                .OrderByDescending(static table => table.Score)
                .First())
            .OrderByDescending(static table => table.Score)
            .ThenBy(static table => table.Name, StringComparer.Ordinal)
            .Take(itemLimit)
            .ToArray();

        return new LocalStructuredContentShape(
            Kind: candidate.Kind,
            Status: orderedTables.Length == 0
                ? LocalStructuredContentShapeStatus.NoMessageShape
                : LocalStructuredContentShapeStatus.Candidate,
            PathHash: HashPathHint(candidate.PathHint),
            PathHint: candidate.PathHint,
            Evidence: orderedTables.Length == 0
                ? "json opened read-only; no message-like key shape found"
                : "json opened read-only; only key names and inferred roles returned",
            Tables: orderedTables,
            KeywordHits: Array.Empty<LocalStructuredContentKeywordHit>());
    }

    private static void CollectJsonContentShapes(
        JsonElement element,
        string path,
        List<LocalStructuredContentTableShape> tables,
        int itemLimit)
    {
        if (tables.Count >= itemLimit)
        {
            return;
        }

        if (element.ValueKind == JsonValueKind.Object)
        {
            TryAddJsonObjectShape(element, path, tables);
            foreach (var property in element.EnumerateObject())
            {
                if (tables.Count >= itemLimit)
                {
                    return;
                }

                if (property.Value.ValueKind is JsonValueKind.Object or JsonValueKind.Array)
                {
                    CollectJsonContentShapes(
                        property.Value,
                        path + "." + SanitizeStructureName(property.Name),
                        tables,
                        itemLimit);
                }
            }

            return;
        }

        if (element.ValueKind != JsonValueKind.Array)
        {
            return;
        }

        var firstObject = element.EnumerateArray()
            .FirstOrDefault(static child => child.ValueKind == JsonValueKind.Object);
        if (firstObject.ValueKind == JsonValueKind.Object)
        {
            TryAddJsonObjectShape(firstObject, path + "[]", tables);
            CollectJsonContentShapes(firstObject, path + "[]", tables, itemLimit);
        }
    }

    private static void TryAddJsonObjectShape(
        JsonElement element,
        string path,
        List<LocalStructuredContentTableShape> tables)
    {
        var properties = element.EnumerateObject()
            .Select(static property => property.Name)
            .ToArray();
        if (properties.Length == 0 || LooksLikeConfigurationObject(properties))
        {
            return;
        }

        var fields = properties
            .Select(static property => new
            {
                Name = property,
                Role = ClassifyColumnRole(property),
            })
            .Where(static field => field.Role != LocalStructuredContentFieldRole.Unknown)
            .Select(static field => new LocalStructuredContentFieldShape(
                Name: SanitizeStructureName(field.Name),
                Role: field.Role,
                NonEmptySampleCount: 0,
                MinLength: 0,
                MaxLength: 0,
                SampleValueHashes: Array.Empty<string>()))
            .ToArray();
        var hasTextRole = fields.Any(static field => field.Role == LocalStructuredContentFieldRole.Text);
        var hasSenderRole = fields.Any(static field => field.Role == LocalStructuredContentFieldRole.Sender);
        var hasIdentityRole = fields.Any(static field =>
            field.Role is LocalStructuredContentFieldRole.Conversation
                or LocalStructuredContentFieldRole.MessageId);
        var hasOrderingRole = fields.Any(static field =>
            field.Role is LocalStructuredContentFieldRole.Timestamp
                or LocalStructuredContentFieldRole.MessageId);
        if (!hasTextRole || !hasSenderRole || !hasIdentityRole || !hasOrderingRole)
        {
            return;
        }

        var score = fields.Sum(static field => ScoreRole(field.Role));
        tables.Add(new LocalStructuredContentTableShape(
            Name: SanitizeJsonPath(path),
            RowCount: 0,
            Score: score,
            Evidence: "roleScore=" + score + " source=json-keys-only",
            Fields: fields));
    }

    private static bool LooksLikeConfigurationObject(IReadOnlyList<string> propertyNames)
    {
        var configLikeCount = propertyNames.Count(static name =>
        {
            var normalized = NormalizeIdentifier(name);
            return ContainsAny(
                normalized,
                "enable",
                "enabled",
                "disable",
                "disabled",
                "timeout",
                "permission",
                "config",
                "switch",
                "limit",
                "style",
                "optimize",
                "fix",
                "setting");
        });

        return configLikeCount >= Math.Max(2, propertyNames.Count / 3);
    }

    private static void CollectJsonStructure(
        JsonElement element,
        string path,
        List<LocalStructuredSourceStructureItem> items,
        int itemLimit)
    {
        if (items.Count >= itemLimit)
        {
            return;
        }

        if (element.ValueKind == JsonValueKind.Object)
        {
            var propertyNames = element.EnumerateObject()
                .Select(static property => SanitizeStructureName(property.Name))
                .Take(itemLimit)
                .ToArray();
            items.Add(new LocalStructuredSourceStructureItem(
                Kind: LocalStructuredSourceStructureKind.JsonObject,
                Name: SanitizeJsonPath(path),
                ChildNames: propertyNames,
                Evidence: "propertyCount=" + propertyNames.Length));

            foreach (var property in element.EnumerateObject())
            {
                if (items.Count >= itemLimit)
                {
                    return;
                }

                if (property.Value.ValueKind is JsonValueKind.Object or JsonValueKind.Array)
                {
                    CollectJsonStructure(property.Value, path + "." + SanitizeStructureName(property.Name), items, itemLimit);
                }
            }
        }
        else if (element.ValueKind == JsonValueKind.Array)
        {
            items.Add(new LocalStructuredSourceStructureItem(
                Kind: LocalStructuredSourceStructureKind.JsonArray,
                Name: SanitizeJsonPath(path),
                ChildNames: new[] { "length=" + element.GetArrayLength() },
                Evidence: "array-shape-only"));

            var firstStructuredElement = element.EnumerateArray()
                .FirstOrDefault(static child => child.ValueKind is JsonValueKind.Object or JsonValueKind.Array);
            if (firstStructuredElement.ValueKind is JsonValueKind.Object or JsonValueKind.Array)
            {
                CollectJsonStructure(firstStructuredElement, path + "[]", items, itemLimit);
            }
        }
    }

    private LocalStructuredSourceInspection InspectLevelDb(
        LocalStructuredSourceCandidate candidate,
        string path,
        int itemLimit)
    {
        var childNames = Directory.EnumerateFiles(path)
            .GroupBy(static file => Path.GetExtension(file).ToLowerInvariant())
            .OrderBy(static group => group.Key, StringComparer.OrdinalIgnoreCase)
            .Take(itemLimit)
            .Select(static group => (group.Key.Length == 0 ? "(no-extension)" : group.Key) + ":" + group.Count())
            .ToArray();

        return new LocalStructuredSourceInspection(
            Kind: candidate.Kind,
            Status: LocalStructuredSourceInspectionStatus.Inspected,
            PathHint: candidate.PathHint,
            Evidence: "leveldb file-group inspection; key/value content not read",
            StructureItems: new[]
            {
                new LocalStructuredSourceStructureItem(
                    Kind: LocalStructuredSourceStructureKind.LevelDbFileGroup,
                    Name: "files",
                    ChildNames: childNames,
                    Evidence: "fileGroupCount=" + childNames.Length),
            });
    }

    private static IReadOnlyList<LocalStructuredContentKeywordHit> CountLevelDbKeywordHits(
        string path,
        int itemLimit)
    {
        var counts = LevelDbShapeKeywords.ToDictionary(
            static keyword => keyword,
            static _ => 0,
            StringComparer.OrdinalIgnoreCase);
        foreach (var file in Directory.EnumerateFiles(path)
                     .Where(static file => Path.GetExtension(file).Equals(".ldb", StringComparison.OrdinalIgnoreCase)
                         || Path.GetExtension(file).Equals(".log", StringComparison.OrdinalIgnoreCase))
                     .OrderByDescending(File.GetLastWriteTimeUtc)
                     .Take(itemLimit))
        {
            byte[] bytes;
            try
            {
                bytes = File.ReadAllBytes(file);
            }
            catch (IOException)
            {
                continue;
            }
            catch (UnauthorizedAccessException)
            {
                continue;
            }

            var content = Encoding.UTF8.GetString(bytes);
            foreach (var keyword in LevelDbShapeKeywords)
            {
                counts[keyword] += CountOccurrences(content, keyword);
            }
        }

        return counts
            .Where(static pair => pair.Value > 0)
            .OrderByDescending(static pair => pair.Value)
            .ThenBy(static pair => pair.Key, StringComparer.OrdinalIgnoreCase)
            .Select(static pair => new LocalStructuredContentKeywordHit(pair.Key, pair.Value))
            .ToArray();
    }

    private static LocalStructuredSourceInspection CreateSkippedInspection(
        LocalStructuredSourceCandidate candidate,
        string evidence)
    {
        return new LocalStructuredSourceInspection(
            Kind: candidate.Kind,
            Status: LocalStructuredSourceInspectionStatus.Skipped,
            PathHint: candidate.PathHint,
            Evidence: evidence,
            StructureItems: Array.Empty<LocalStructuredSourceStructureItem>());
    }

    private static LocalStructuredSourceInspection CreateFailedInspection(
        LocalStructuredSourceCandidate candidate,
        string evidence)
    {
        return new LocalStructuredSourceInspection(
            Kind: candidate.Kind,
            Status: LocalStructuredSourceInspectionStatus.Failed,
            PathHint: candidate.PathHint,
            Evidence: evidence,
            StructureItems: Array.Empty<LocalStructuredSourceStructureItem>());
    }

    private LocalStructuredContentShape CreateContentShape(
        LocalStructuredSourceCandidate candidate,
        LocalStructuredContentShapeStatus status,
        string evidence)
    {
        return new LocalStructuredContentShape(
            Kind: candidate.Kind,
            Status: status,
            PathHash: HashPathHint(candidate.PathHint),
            PathHint: candidate.PathHint,
            Evidence: evidence,
            Tables: Array.Empty<LocalStructuredContentTableShape>(),
            KeywordHits: Array.Empty<LocalStructuredContentKeywordHit>());
    }

    private string HashPathHint(string pathHint)
    {
        var actualPath = ResolvePathHint(pathHint);
        return string.IsNullOrWhiteSpace(actualPath)
            ? string.Empty
            : Sha256Hex(Path.GetFullPath(actualPath).ToLowerInvariant());
    }

    private static IEnumerable<string> EnumerateFileSystemEntries(string root)
    {
        var pending = new Stack<string>();
        pending.Push(root);

        while (pending.Count > 0)
        {
            var current = pending.Pop();
            string[] entries;
            try
            {
                entries = Directory.GetFileSystemEntries(current);
            }
            catch (UnauthorizedAccessException)
            {
                continue;
            }
            catch (IOException)
            {
                continue;
            }

            foreach (var entry in entries)
            {
                yield return entry;
                if (Directory.Exists(entry))
                {
                    if (LooksLikeLevelDbDirectory(entry))
                    {
                        continue;
                    }

                    pending.Push(entry);
                }
            }
        }
    }

    private LocalStructuredSourceCandidate? TryCreateCandidate(string path)
    {
        try
        {
            if (Directory.Exists(path))
            {
                return TryCreateDirectoryCandidate(path);
            }

            if (File.Exists(path))
            {
                return TryCreateFileCandidate(path);
            }
        }
        catch (UnauthorizedAccessException)
        {
            return null;
        }
        catch (IOException)
        {
            return null;
        }

        return null;
    }

    private LocalStructuredSourceChangeSnapshot? TryCreateChangeSnapshot(string path)
    {
        try
        {
            var kind = Directory.Exists(path)
                ? (LooksLikeLevelDbDirectory(path)
                    ? LocalStructuredSourceCandidateKind.LevelDbStore
                    : LocalStructuredSourceCandidateKind.Unknown)
                : ClassifyFile(path);
            if (kind == LocalStructuredSourceCandidateKind.Unknown)
            {
                return null;
            }

            var (sizeBytes, lastWriteTime) = Directory.Exists(path)
                ? GetDirectoryChangeMetadata(path)
                : GetFileChangeMetadata(path);
            var fullPath = Path.GetFullPath(path);
            return new LocalStructuredSourceChangeSnapshot(
                Kind: kind,
                FullPath: fullPath,
                PathHash: Sha256Hex(fullPath.ToLowerInvariant()),
                SizeBytes: sizeBytes,
                LastWriteTime: lastWriteTime);
        }
        catch (UnauthorizedAccessException)
        {
            return null;
        }
        catch (IOException)
        {
            return null;
        }
    }

    private static LocalStructuredSourceChange CreateChange(
        LocalStructuredSourceChangeSnapshot current,
        IReadOnlyDictionary<string, LocalStructuredSourceChangeSnapshot> previousBaseline)
    {
        if (!previousBaseline.TryGetValue(current.PathHash, out var previous))
        {
            return new LocalStructuredSourceChange(
                Kind: current.Kind,
                ChangeKind: LocalStructuredSourceChangeKind.Baseline,
                PathHash: current.PathHash,
                SizeBytes: current.SizeBytes,
                LastWriteTime: current.LastWriteTime,
                PreviousSizeBytes: 0,
                PreviousLastWriteTime: null,
                RelatedPathHash: GetRelatedPathHash(current),
                RelatedHeaderKind: GetRelatedHeaderKind(current));
        }

        var changeKind = current.SizeBytes == previous.SizeBytes
            && current.LastWriteTime == previous.LastWriteTime
            ? LocalStructuredSourceChangeKind.Unchanged
            : LocalStructuredSourceChangeKind.Modified;
        return new LocalStructuredSourceChange(
            Kind: current.Kind,
            ChangeKind: changeKind,
            PathHash: current.PathHash,
            SizeBytes: current.SizeBytes,
            LastWriteTime: current.LastWriteTime,
            PreviousSizeBytes: previous.SizeBytes,
            PreviousLastWriteTime: previous.LastWriteTime,
            RelatedPathHash: GetRelatedPathHash(current),
            RelatedHeaderKind: GetRelatedHeaderKind(current));
    }

    private static string GetRelatedPathHash(LocalStructuredSourceChangeSnapshot current)
    {
        if (current.Kind != LocalStructuredSourceCandidateKind.SqliteWriteAheadLog)
        {
            return string.Empty;
        }

        var relatedPath = GetSqliteWalBasePath(current.FullPath);
        return relatedPath is null
            ? string.Empty
            : Sha256Hex(relatedPath.ToLowerInvariant());
    }

    private static string GetRelatedHeaderKind(LocalStructuredSourceChangeSnapshot current)
    {
        if (current.Kind != LocalStructuredSourceCandidateKind.SqliteWriteAheadLog)
        {
            return string.Empty;
        }

        var relatedPath = GetSqliteWalBasePath(current.FullPath);
        if (relatedPath is null)
        {
            return "missing";
        }

        if (!File.Exists(relatedPath))
        {
            return "missing";
        }

        try
        {
            return HasHeader(relatedPath, SqliteHeader)
                ? "sqlite"
                : "non-sqlite-or-encrypted";
        }
        catch (UnauthorizedAccessException)
        {
            return "unreadable";
        }
        catch (IOException)
        {
            return "unreadable";
        }
    }

    private static string? GetSqliteWalBasePath(string walPath)
    {
        return walPath.EndsWith("-wal", StringComparison.OrdinalIgnoreCase)
            ? walPath[..^4]
            : null;
    }

    private static (long SizeBytes, DateTimeOffset LastWriteTime) GetFileChangeMetadata(string path)
    {
        var file = new FileInfo(path);
        return (file.Length, new DateTimeOffset(file.LastWriteTimeUtc, TimeSpan.Zero));
    }

    private static (long SizeBytes, DateTimeOffset LastWriteTime) GetDirectoryChangeMetadata(string path)
    {
        var directory = new DirectoryInfo(path);
        long sizeBytes = 0;
        var lastWriteTime = directory.LastWriteTimeUtc;
        foreach (var file in directory.EnumerateFiles())
        {
            sizeBytes += file.Length;
            if (file.LastWriteTimeUtc > lastWriteTime)
            {
                lastWriteTime = file.LastWriteTimeUtc;
            }
        }

        return (sizeBytes, new DateTimeOffset(lastWriteTime, TimeSpan.Zero));
    }

    private LocalStructuredSourceCandidate? TryCreateDirectoryCandidate(string path)
    {
        if (!LooksLikeLevelDbDirectory(path))
        {
            return null;
        }

        var directory = new DirectoryInfo(path);
        var lastWriteTime = new DateTimeOffset(directory.LastWriteTimeUtc, TimeSpan.Zero);
        return new LocalStructuredSourceCandidate(
            Kind: LocalStructuredSourceCandidateKind.LevelDbStore,
            PathHint: RedactPath(path),
            SizeBytes: 0,
            LastWriteTime: lastWriteTime,
            Evidence: "directory=leveldb-like contains metadata files; content not read");
    }

    private LocalStructuredSourceCandidate? TryCreateFileCandidate(string path)
    {
        var kind = ClassifyFile(path);
        if (kind == LocalStructuredSourceCandidateKind.Unknown)
        {
            return null;
        }

        var file = new FileInfo(path);
        return new LocalStructuredSourceCandidate(
            Kind: kind,
            PathHint: RedactPath(path),
            SizeBytes: file.Length,
            LastWriteTime: new DateTimeOffset(file.LastWriteTimeUtc, TimeSpan.Zero),
            Evidence: "extension="
                + file.Extension.ToLowerInvariant()
                + " sizeBytes="
                + file.Length
                + " content=not-read");
    }

    private static bool LooksLikeLevelDbDirectory(string path)
    {
        var directoryName = Path.GetFileName(path);
        if (directoryName.Contains("leveldb", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        return File.Exists(Path.Combine(path, "CURRENT"))
            && Directory.EnumerateFiles(path, "*.ldb").Take(1).Any();
    }

    private static LocalStructuredSourceCandidateKind ClassifyFile(string path)
    {
        if (path.EndsWith("-wal", StringComparison.OrdinalIgnoreCase)
            || path.EndsWith(".db-wal", StringComparison.OrdinalIgnoreCase)
            || path.EndsWith(".sqlite-wal", StringComparison.OrdinalIgnoreCase))
        {
            return LocalStructuredSourceCandidateKind.SqliteWriteAheadLog;
        }

        var extension = Path.GetExtension(path);
        if (IsSqliteExtension(extension))
        {
            return LocalStructuredSourceCandidateKind.SqliteDatabase;
        }

        if (extension.Equals(".log", StringComparison.OrdinalIgnoreCase)
            || extension.Equals(".txt", StringComparison.OrdinalIgnoreCase))
        {
            return LocalStructuredSourceCandidateKind.LogFile;
        }

        if (extension.Equals(".json", StringComparison.OrdinalIgnoreCase))
        {
            return LocalStructuredSourceCandidateKind.JsonFile;
        }

        if (extension.Equals(".jpg", StringComparison.OrdinalIgnoreCase)
            || extension.Equals(".jpeg", StringComparison.OrdinalIgnoreCase)
            || extension.Equals(".png", StringComparison.OrdinalIgnoreCase)
            || extension.Equals(".webp", StringComparison.OrdinalIgnoreCase)
            || extension.Equals(".gif", StringComparison.OrdinalIgnoreCase))
        {
            return LocalStructuredSourceCandidateKind.MediaCache;
        }

        return LocalStructuredSourceCandidateKind.Unknown;
    }

    private static bool IsSqliteExtension(string extension)
    {
        return extension.Equals(".db", StringComparison.OrdinalIgnoreCase)
            || extension.Equals(".sqlite", StringComparison.OrdinalIgnoreCase)
            || extension.Equals(".sqlite3", StringComparison.OrdinalIgnoreCase);
    }

    private string RedactPath(string path)
    {
        var fullPath = Path.GetFullPath(path);
        foreach (var variableName in new[] { "LOCALAPPDATA", "APPDATA", "USERPROFILE", "TEMP", "TMP" })
        {
            var value = _environmentVariableSource(variableName);
            if (string.IsNullOrWhiteSpace(value))
            {
                continue;
            }

            var fullValue = Path.GetFullPath(value);
            if (!fullPath.StartsWith(fullValue, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var suffix = fullPath[fullValue.Length..].TrimStart(
                Path.DirectorySeparatorChar,
                Path.AltDirectorySeparatorChar);
            return "%" + variableName + "%"
                + (suffix.Length == 0 ? string.Empty : "\\" + suffix.Replace('/', '\\'));
        }

        return fullPath;
    }

    private string ResolvePathHint(string pathHint)
    {
        if (!pathHint.StartsWith("%", StringComparison.Ordinal))
        {
            return pathHint;
        }

        var closingIndex = pathHint.IndexOf('%', startIndex: 1);
        if (closingIndex <= 1)
        {
            return string.Empty;
        }

        var variableName = pathHint[1..closingIndex];
        var value = _environmentVariableSource(variableName);
        if (string.IsNullOrWhiteSpace(value))
        {
            return string.Empty;
        }

        var suffix = pathHint[(closingIndex + 1)..].TrimStart('\\', '/');
        return suffix.Length == 0 ? value : Path.Combine(value, suffix);
    }

    private static string BuildRecommendation(int rootCount, int candidateCount)
    {
        if (rootCount == 0)
        {
            return "No DingTalk local data root was found. Keep UIA as trigger and re-run after DingTalk is started.";
        }

        if (candidateCount == 0)
        {
            return "DingTalk local data roots exist, but no SQLite, LevelDB, log, JSON, or media-cache candidates were found.";
        }

        return "Read-only local structured source candidates were found. Do not parse file content until the operator approves the specific source type.";
    }

    private static string BuildInspectionRecommendation(int candidateCount, int inspectedCount)
    {
        if (candidateCount == 0)
        {
            return "No inspectable local structured source candidate was found.";
        }

        if (inspectedCount == 0)
        {
            return "Local source candidates exist, but none exposed schema/key metadata safely.";
        }

        return "Schema/key metadata was inspected without returning message values. Parsing content still requires separate explicit approval.";
    }

    private static string BuildChangeRecommendation(
        int rootCount,
        int candidateCount,
        int returnedChangeCount,
        bool resetBaseline)
    {
        if (rootCount == 0)
        {
            return "No DingTalk local data root was found. Start DingTalk and reset the metadata baseline.";
        }

        if (candidateCount == 0)
        {
            return "No local structured source candidate was available for metadata change tracking.";
        }

        if (resetBaseline)
        {
            return "Metadata baseline was reset. Send one controlled test message, then call this endpoint again without resetBaseline.";
        }

        if (returnedChangeCount == 0)
        {
            return "No candidate metadata changed since the previous baseline. Keep DingTalk active and repeat around a controlled test message.";
        }

        return "Candidate metadata changed. Use pathHash, kind, size, and mtime only to narrow the source; parsing still requires explicit source approval.";
    }

    private static string BuildContentShapeRecommendation(int candidateCount, int actionableCount)
    {
        if (candidateCount == 0)
        {
            return "No local structured source candidate was available for content-shape probing.";
        }

        if (actionableCount == 0)
        {
            return "Local sources were probed without returning values, but no parse-ready message shape was found.";
        }

        return "Content-shape metadata found possible message sources. Values were not returned; parser enablement still requires an explicit source choice.";
    }

    private static LocalStructuredContentFieldRole ClassifyColumnRole(string columnName)
    {
        var normalized = NormalizeIdentifier(columnName);
        if (ContainsAny(normalized, "conversation", "conversationid", "conversationname", "cid", "chatid", "chatname", "groupid", "groupname"))
        {
            return LocalStructuredContentFieldRole.Conversation;
        }

        if (ContainsAny(normalized, "sender", "sendername", "senderid", "fromuid", "fromuser", "nickname", "username", "author"))
        {
            return LocalStructuredContentFieldRole.Sender;
        }

        if (ContainsAny(normalized, "content", "body", "text", "message", "msg", "payload"))
        {
            return LocalStructuredContentFieldRole.Text;
        }

        if (ContainsAny(normalized, "timestamp", "createdat", "createtime", "time", "sentat", "sendtime", "msgtime"))
        {
            return LocalStructuredContentFieldRole.Timestamp;
        }

        if (ContainsAny(normalized, "messageid", "msgid", "mid", "clientmsgid", "servermsgid"))
        {
            return LocalStructuredContentFieldRole.MessageId;
        }

        return LocalStructuredContentFieldRole.Unknown;
    }

    private static string NormalizeIdentifier(string value)
    {
        return value.Replace("_", string.Empty, StringComparison.Ordinal)
            .Replace("-", string.Empty, StringComparison.Ordinal)
            .ToLowerInvariant();
    }

    private static int ScoreRole(LocalStructuredContentFieldRole role)
    {
        return role switch
        {
            LocalStructuredContentFieldRole.Conversation => 3,
            LocalStructuredContentFieldRole.Sender => 3,
            LocalStructuredContentFieldRole.Text => 5,
            LocalStructuredContentFieldRole.Timestamp => 2,
            LocalStructuredContentFieldRole.MessageId => 2,
            _ => 0,
        };
    }

    private static bool ContainsAny(string value, params string[] needles)
    {
        return needles.Any(value.Contains);
    }

    private static bool HasHeader(string path, byte[] expectedHeader)
    {
        using var stream = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        if (stream.Length < expectedHeader.Length)
        {
            return false;
        }

        var buffer = new byte[expectedHeader.Length];
        var read = stream.Read(buffer, 0, buffer.Length);
        return read == expectedHeader.Length && buffer.SequenceEqual(expectedHeader);
    }

    private static int CountOccurrences(string value, string needle)
    {
        if (string.IsNullOrEmpty(value) || string.IsNullOrEmpty(needle))
        {
            return 0;
        }

        var count = 0;
        var index = 0;
        while (index < value.Length)
        {
            var found = value.IndexOf(needle, index, StringComparison.OrdinalIgnoreCase);
            if (found < 0)
            {
                break;
            }

            count++;
            index = found + needle.Length;
        }

        return count;
    }

    private static string Sha256Hex(string value)
    {
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();
    }

    private static string QuoteSqliteIdentifier(string value)
    {
        return "\"" + value.Replace("\"", "\"\"", StringComparison.Ordinal) + "\"";
    }

    private static string SanitizeJsonPath(string value)
    {
        return string.Join(
            ".",
            value.Split('.').Select(static segment =>
            {
                if (segment.EndsWith("[]", StringComparison.Ordinal))
                {
                    var name = segment[..^2];
                    return SanitizeStructureName(name) + "[]";
                }

                return SanitizeStructureName(segment);
            }));
    }

    private static string SanitizeStructureName(string value)
    {
        if (value == "$")
        {
            return value;
        }

        var candidate = value.Trim();
        if (candidate.Length is 0 or > 80)
        {
            return "<dynamic-key>";
        }

        return candidate.All(static character =>
            char.IsAsciiLetterOrDigit(character)
            || character == '_'
            || character == '$')
            ? candidate
            : "<dynamic-key>";
    }

    private static IReadOnlyList<string> GetDefaultRoots()
    {
        return new[]
            {
                Environment.GetEnvironmentVariable("LOCALAPPDATA"),
                Environment.GetEnvironmentVariable("APPDATA"),
                Environment.GetEnvironmentVariable("USERPROFILE"),
            }
            .Where(static value => !string.IsNullOrWhiteSpace(value))
            .Cast<string>()
            .ToArray();
    }
}
