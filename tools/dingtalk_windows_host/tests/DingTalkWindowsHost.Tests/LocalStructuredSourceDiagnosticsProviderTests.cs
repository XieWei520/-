using DingTalkWindowsHost.Automation.StructuredSources;
using DingTalkWindowsHost.Contracts.Models;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class LocalStructuredSourceDiagnosticsProviderTests : IDisposable
{
    private readonly string _tempRoot;

    public LocalStructuredSourceDiagnosticsProviderTests()
    {
        _tempRoot = Path.Combine(Path.GetTempPath(), "dingtalk-local-source-tests-" + Guid.NewGuid());
        Directory.CreateDirectory(_tempRoot);
    }

    [Fact]
    public void GetDiagnostics_reports_structured_candidates_without_reading_file_content()
    {
        var dingTalkRoot = Path.Combine(_tempRoot, "DingTalk");
        Directory.CreateDirectory(dingTalkRoot);
        Directory.CreateDirectory(Path.Combine(dingTalkRoot, "IndexedDB", "messages.leveldb"));
        File.WriteAllText(Path.Combine(dingTalkRoot, "message.sqlite"), "secret-message-body");
        File.WriteAllText(Path.Combine(dingTalkRoot, "IndexedDB", "messages.leveldb", "CURRENT"), "MANIFEST-000001");
        File.WriteAllText(Path.Combine(dingTalkRoot, "app.log"), "secret-log-body");
        var provider = new LocalStructuredSourceDiagnosticsProvider(
            rootSource: () => new[] { _tempRoot },
            environmentVariableSource: static _ => null);

        var diagnostics = provider.GetDiagnostics(candidateLimit: 10);

        Assert.Equal(StructuredSourceStatus.NeedsManualApproval, diagnostics.Status);
        Assert.Contains(
            diagnostics.Candidates,
            candidate => candidate.Kind == LocalStructuredSourceCandidateKind.SqliteDatabase
                && candidate.PathHint.EndsWith("message.sqlite", StringComparison.OrdinalIgnoreCase));
        Assert.Contains(
            diagnostics.Candidates,
            candidate => candidate.Kind == LocalStructuredSourceCandidateKind.LevelDbStore
                && candidate.PathHint.Contains("messages.leveldb", StringComparison.OrdinalIgnoreCase));
        Assert.Contains(
            diagnostics.Candidates,
            candidate => candidate.Kind == LocalStructuredSourceCandidateKind.LogFile
                && candidate.PathHint.EndsWith("app.log", StringComparison.OrdinalIgnoreCase));
        Assert.DoesNotContain("secret-message-body", diagnostics.Recommendation, StringComparison.Ordinal);
        Assert.DoesNotContain("secret-log-body", string.Join("\n", diagnostics.Candidates.Select(c => c.Evidence)), StringComparison.Ordinal);
    }

    [Fact]
    public void GetDiagnostics_redacts_known_user_roots_from_path_hints()
    {
        var localAppData = Path.Combine(_tempRoot, "LocalAppData");
        var dingTalkRoot = Path.Combine(localAppData, "DingTalk");
        Directory.CreateDirectory(dingTalkRoot);
        File.WriteAllText(Path.Combine(dingTalkRoot, "cache.db"), string.Empty);
        var provider = new LocalStructuredSourceDiagnosticsProvider(
            rootSource: () => new[] { localAppData },
            environmentVariableSource: name => string.Equals(name, "LOCALAPPDATA", StringComparison.OrdinalIgnoreCase)
                ? localAppData
                : null);

        var diagnostics = provider.GetDiagnostics(candidateLimit: 10);

        var candidate = Assert.Single(diagnostics.Candidates);
        Assert.StartsWith("%LOCALAPPDATA%", candidate.PathHint, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain(localAppData, candidate.PathHint, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void GetDiagnostics_limits_candidates_and_orders_recent_files_first()
    {
        var dingTalkRoot = Path.Combine(_tempRoot, "DingTalk");
        Directory.CreateDirectory(dingTalkRoot);
        var older = Path.Combine(dingTalkRoot, "older.db");
        var newer = Path.Combine(dingTalkRoot, "newer.db");
        File.WriteAllText(older, string.Empty);
        File.WriteAllText(newer, string.Empty);
        File.SetLastWriteTimeUtc(older, new DateTime(2026, 5, 14, 0, 0, 0, DateTimeKind.Utc));
        File.SetLastWriteTimeUtc(newer, new DateTime(2026, 5, 15, 0, 0, 0, DateTimeKind.Utc));
        var provider = new LocalStructuredSourceDiagnosticsProvider(
            rootSource: () => new[] { _tempRoot },
            environmentVariableSource: static _ => null);

        var diagnostics = provider.GetDiagnostics(candidateLimit: 1);

        var candidate = Assert.Single(diagnostics.Candidates);
        Assert.EndsWith("newer.db", candidate.PathHint, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void GetChangeDiagnostics_reports_metadata_deltas_without_paths_or_content()
    {
        var dingTalkRoot = Path.Combine(_tempRoot, "DingTalk");
        Directory.CreateDirectory(dingTalkRoot);
        var databasePath = Path.Combine(dingTalkRoot, "message.sqlite");
        File.WriteAllText(databasePath, "secret-before");
        var provider = new LocalStructuredSourceDiagnosticsProvider(
            rootSource: () => new[] { _tempRoot },
            environmentVariableSource: static _ => null);

        var baseline = provider.GetChangeDiagnostics(candidateLimit: 10, resetBaseline: true);

        var baselineChange = Assert.Single(baseline.Changes);
        Assert.Equal(LocalStructuredSourceChangeKind.Baseline, baselineChange.ChangeKind);
        Assert.Equal(64, baselineChange.PathHash.Length);

        File.AppendAllText(databasePath, "secret-after");
        File.SetLastWriteTimeUtc(databasePath, DateTime.UtcNow.AddSeconds(1));

        var delta = provider.GetChangeDiagnostics(candidateLimit: 10, resetBaseline: false);

        var changed = Assert.Single(delta.Changes);
        Assert.Equal(LocalStructuredSourceChangeKind.Modified, changed.ChangeKind);
        Assert.Equal(LocalStructuredSourceCandidateKind.SqliteDatabase, changed.Kind);
        Assert.Equal(baselineChange.PathHash, changed.PathHash);
        Assert.True(changed.SizeBytes > changed.PreviousSizeBytes);
        var serialized = System.Text.Json.JsonSerializer.Serialize(delta);
        Assert.DoesNotContain(databasePath, serialized, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("message.sqlite", serialized, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("secret-before", serialized, StringComparison.Ordinal);
        Assert.DoesNotContain("secret-after", serialized, StringComparison.Ordinal);
    }

    [Fact]
    public void GetChangeDiagnostics_reports_wal_related_base_metadata_without_paths()
    {
        var dingTalkRoot = Path.Combine(_tempRoot, "DingTalk");
        Directory.CreateDirectory(dingTalkRoot);
        var databasePath = Path.Combine(dingTalkRoot, "message.sqlite");
        File.WriteAllBytes(databasePath, System.Text.Encoding.ASCII.GetBytes("SQLite format 3\0"));
        var walPath = databasePath + "-wal";
        File.WriteAllBytes(walPath, new byte[] { 0x37, 0x7f, 0x06, 0x82 });
        var provider = new LocalStructuredSourceDiagnosticsProvider(
            rootSource: () => new[] { _tempRoot },
            environmentVariableSource: static _ => null);

        var baseline = provider.GetChangeDiagnostics(candidateLimit: 10, resetBaseline: true);

        File.WriteAllBytes(walPath, new byte[] { 0x37, 0x7f, 0x06, 0x82, 0x01 });
        File.SetLastWriteTimeUtc(walPath, DateTime.UtcNow.AddSeconds(1));
        var delta = provider.GetChangeDiagnostics(candidateLimit: 10, resetBaseline: false);

        var walBaseline = Assert.Single(
            baseline.Changes,
            change => change.Kind == LocalStructuredSourceCandidateKind.SqliteWriteAheadLog);
        var changed = Assert.Single(delta.Changes);
        Assert.Equal(LocalStructuredSourceCandidateKind.SqliteWriteAheadLog, changed.Kind);
        Assert.Equal(LocalStructuredSourceChangeKind.Modified, changed.ChangeKind);
        Assert.Equal(64, changed.RelatedPathHash.Length);
        Assert.NotEqual(walBaseline.PathHash, changed.RelatedPathHash);
        Assert.Equal("sqlite", changed.RelatedHeaderKind);
        var serialized = System.Text.Json.JsonSerializer.Serialize(delta);
        Assert.DoesNotContain(databasePath, serialized, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("message.sqlite", serialized, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void GetDiagnostics_reports_unavailable_when_no_dingtalk_roots_exist()
    {
        var provider = new LocalStructuredSourceDiagnosticsProvider(
            rootSource: () => new[] { _tempRoot },
            environmentVariableSource: static _ => null);

        var diagnostics = provider.GetDiagnostics(candidateLimit: 10);

        Assert.Equal(StructuredSourceStatus.Unavailable, diagnostics.Status);
        Assert.Empty(diagnostics.Candidates);
        Assert.Contains("No DingTalk local data root", diagnostics.Recommendation, StringComparison.Ordinal);
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempRoot))
        {
            Directory.Delete(_tempRoot, recursive: true);
        }
    }
}
