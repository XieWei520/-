using Microsoft.Data.Sqlite;

namespace DingTalkWindowsHost.Storage.Db;

public sealed class SqliteDatabase : IAsyncDisposable
{
    private readonly SqliteConnection? _sharedConnection;

    private SqliteDatabase(string connectionString, SqliteConnection? sharedConnection)
    {
        ConnectionString = connectionString;
        _sharedConnection = sharedConnection;
    }

    public string ConnectionString { get; }

    public bool UsesSharedConnection => _sharedConnection is not null;

    public static async Task<SqliteDatabase> CreateAsync(string databasePath, CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(databasePath);

        var directory = Path.GetDirectoryName(Path.GetFullPath(databasePath));
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }

        var builder = new SqliteConnectionStringBuilder
        {
            DataSource = databasePath,
        };

        var database = new SqliteDatabase(builder.ToString(), sharedConnection: null);
        await database.InitializeAsync(cancellationToken);
        return database;
    }

    public static async Task<SqliteDatabase> CreateInMemoryAsync(CancellationToken cancellationToken)
    {
        var builder = new SqliteConnectionStringBuilder
        {
            DataSource = "dingtalk-host-tests-" + Guid.NewGuid().ToString("N"),
            Mode = SqliteOpenMode.Memory,
            Cache = SqliteCacheMode.Shared,
        };
        var connection = new SqliteConnection(builder.ToString());
        await connection.OpenAsync(cancellationToken);

        var database = new SqliteDatabase(builder.ToString(), connection);
        await database.InitializeAsync(cancellationToken);
        return database;
    }

    public async Task<SqliteConnection> OpenConnectionAsync(CancellationToken cancellationToken)
    {
        if (_sharedConnection is not null)
        {
            return _sharedConnection;
        }

        var connection = new SqliteConnection(ConnectionString);
        await connection.OpenAsync(cancellationToken);
        return connection;
    }

    public async ValueTask DisposeAsync()
    {
        if (_sharedConnection is not null)
        {
            await _sharedConnection.DisposeAsync();
        }
    }

    private async Task InitializeAsync(CancellationToken cancellationToken)
    {
        var schema = await LoadSchemaAsync(cancellationToken);
        var connection = await OpenConnectionAsync(cancellationToken);
        await using var disposable = _sharedConnection is null ? connection : null;
        await using var command = connection.CreateCommand();
        command.CommandText = schema;
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task<string> LoadSchemaAsync(CancellationToken cancellationToken)
    {
        var baseDirectory = AppContext.BaseDirectory;
        var candidate = Path.Combine(baseDirectory, "Db", "Schema.sql");
        if (!File.Exists(candidate))
        {
            candidate = Path.Combine(
                baseDirectory,
                "..",
                "..",
                "..",
                "Db",
                "Schema.sql");
        }

        return File.Exists(candidate)
            ? await File.ReadAllTextAsync(candidate, cancellationToken)
            : EmbeddedSchema;
    }

    private const string EmbeddedSchema = """
CREATE TABLE IF NOT EXISTS raw_events (
  event_id TEXT PRIMARY KEY,
  source_conversation_id TEXT NOT NULL,
  source_conversation_name TEXT NOT NULL,
  embedded_source_name TEXT NOT NULL,
  sender_name TEXT NOT NULL,
  observed_at TEXT NOT NULL,
  text TEXT NOT NULL,
  local_image_path TEXT NOT NULL,
  capture_source TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  dedupe_key TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS forward_jobs (
  job_id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL,
  status TEXT NOT NULL,
  attempts INTEGER NOT NULL,
  last_error TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS delivery_logs (
  log_id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL,
  outcome TEXT NOT NULL,
  detail TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS conversation_trigger_snapshots (
  snapshot_id TEXT PRIMARY KEY,
  observed_at TEXT NOT NULL,
  readiness TEXT NOT NULL,
  conversation_count INTEGER NOT NULL,
  unread_count INTEGER NOT NULL,
  selected_conversation_name TEXT NOT NULL,
  first_unread_conversation_name TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  summary TEXT NOT NULL
);
""";
}
