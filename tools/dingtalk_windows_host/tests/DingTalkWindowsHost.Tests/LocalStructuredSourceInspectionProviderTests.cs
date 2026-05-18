using System.Text.Json;
using DingTalkWindowsHost.Automation.StructuredSources;
using DingTalkWindowsHost.Contracts.Models;
using Microsoft.Data.Sqlite;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class LocalStructuredSourceInspectionProviderTests : IDisposable
{
    private readonly string _tempRoot;

    public LocalStructuredSourceInspectionProviderTests()
    {
        _tempRoot = Path.Combine(Path.GetTempPath(), "dingtalk-local-inspection-tests-" + Guid.NewGuid());
        Directory.CreateDirectory(_tempRoot);
    }

    [Fact]
    public void GetInspectionDiagnostics_reports_sqlite_tables_and_columns_without_row_values()
    {
        var dingTalkRoot = Path.Combine(_tempRoot, "DingTalk");
        Directory.CreateDirectory(dingTalkRoot);
        var databasePath = Path.Combine(dingTalkRoot, "messages.sqlite");
        using (var connection = new SqliteConnection("Data Source=" + databasePath))
        {
            connection.Open();
            using var command = connection.CreateCommand();
            command.CommandText = """
                CREATE TABLE messages (
                    id INTEGER PRIMARY KEY,
                    sender_name TEXT,
                    body_text TEXT
                );
                INSERT INTO messages (sender_name, body_text)
                VALUES ('secret-sender-value', 'secret-message-body');
                """;
            command.ExecuteNonQuery();
        }
        SqliteConnection.ClearAllPools();

        var provider = new LocalStructuredSourceDiagnosticsProvider(
            rootSource: () => new[] { _tempRoot },
            environmentVariableSource: static _ => null);

        var diagnostics = provider.GetInspectionDiagnostics(candidateLimit: 10, itemLimit: 10);

        var inspection = Assert.Single(diagnostics.Inspections);
        Assert.Equal(LocalStructuredSourceInspectionStatus.Inspected, inspection.Status);
        var table = Assert.Single(inspection.StructureItems);
        Assert.Equal(LocalStructuredSourceStructureKind.SqliteTable, table.Kind);
        Assert.Equal("messages", table.Name);
        Assert.Contains("sender_name", table.ChildNames);
        Assert.Contains("body_text", table.ChildNames);
        var serialized = JsonSerializer.Serialize(diagnostics);
        Assert.DoesNotContain("secret-sender-value", serialized, StringComparison.Ordinal);
        Assert.DoesNotContain("secret-message-body", serialized, StringComparison.Ordinal);
    }

    [Fact]
    public void GetInspectionDiagnostics_reports_locked_sqlite_tables_and_columns_from_snapshot_without_values()
    {
        var dingTalkRoot = Path.Combine(_tempRoot, "DingTalk");
        Directory.CreateDirectory(dingTalkRoot);
        var databasePath = Path.Combine(dingTalkRoot, "messages.sqlite");
        using (var connection = new SqliteConnection("Data Source=" + databasePath))
        {
            connection.Open();
            using var command = connection.CreateCommand();
            command.CommandText = """
                CREATE TABLE messages (
                    id INTEGER PRIMARY KEY,
                    sender_name TEXT,
                    body_text TEXT
                );
                INSERT INTO messages (sender_name, body_text)
                VALUES ('secret-locked-sender', 'secret-locked-message');
                """;
            command.ExecuteNonQuery();
        }
        SqliteConnection.ClearAllPools();

        var provider = new LocalStructuredSourceDiagnosticsProvider(
            rootSource: () => new[] { _tempRoot },
            environmentVariableSource: static _ => null);

        LocalStructuredSourceInspectionDiagnosticsResult diagnostics;
        using (var lockConnection = new SqliteConnection(
            "Data Source=" + databasePath + ";Default Timeout=1;Pooling=False"))
        {
            lockConnection.Open();
            using var lockCommand = lockConnection.CreateCommand();
            lockCommand.CommandText = "PRAGMA locking_mode=EXCLUSIVE; BEGIN EXCLUSIVE;";
            lockCommand.ExecuteNonQuery();

            diagnostics = provider.GetInspectionDiagnostics(candidateLimit: 10, itemLimit: 10);
        }
        SqliteConnection.ClearAllPools();

        var inspection = Assert.Single(diagnostics.Inspections);
        Assert.Equal(LocalStructuredSourceInspectionStatus.Inspected, inspection.Status);
        Assert.Contains("snapshot", inspection.Evidence, StringComparison.OrdinalIgnoreCase);
        var table = Assert.Single(inspection.StructureItems);
        Assert.Equal("messages", table.Name);
        Assert.Contains("sender_name", table.ChildNames);
        Assert.Contains("body_text", table.ChildNames);
        var serialized = JsonSerializer.Serialize(diagnostics);
        Assert.DoesNotContain("secret-locked-sender", serialized, StringComparison.Ordinal);
        Assert.DoesNotContain("secret-locked-message", serialized, StringComparison.Ordinal);
    }

    [Fact]
    public void GetInspectionDiagnostics_reports_json_keys_without_values()
    {
        var dingTalkRoot = Path.Combine(_tempRoot, "DingTalk");
        Directory.CreateDirectory(dingTalkRoot);
        File.WriteAllText(
            Path.Combine(dingTalkRoot, "payload.json"),
            """
            {
              "messages": [
                {
                  "sender": "secret-json-sender",
                  "body": "secret-json-message",
                  "meta": { "conversation": "secret-json-conversation" }
                }
              ],
              "secret-dynamic-key@home": { "secret-child-key@home": "secret-dynamic-value" }
            }
            """);
        var provider = new LocalStructuredSourceDiagnosticsProvider(
            rootSource: () => new[] { _tempRoot },
            environmentVariableSource: static _ => null);

        var diagnostics = provider.GetInspectionDiagnostics(candidateLimit: 10, itemLimit: 10);

        var inspection = Assert.Single(diagnostics.Inspections);
        Assert.Equal(LocalStructuredSourceInspectionStatus.Inspected, inspection.Status);
        Assert.Contains(
            inspection.StructureItems,
            item => item.Kind == LocalStructuredSourceStructureKind.JsonObject
                && item.Name == "$"
                && item.ChildNames.Contains("messages"));
        Assert.Contains(
            inspection.StructureItems,
            item => item.Name == "$.messages[]"
                && item.ChildNames.Contains("sender")
                && item.ChildNames.Contains("body")
                && item.ChildNames.Contains("meta"));
        var serialized = JsonSerializer.Serialize(diagnostics);
        Assert.DoesNotContain("secret-json-sender", serialized, StringComparison.Ordinal);
        Assert.DoesNotContain("secret-json-message", serialized, StringComparison.Ordinal);
        Assert.DoesNotContain("secret-json-conversation", serialized, StringComparison.Ordinal);
        Assert.DoesNotContain("secret-dynamic-key", serialized, StringComparison.Ordinal);
        Assert.DoesNotContain("secret-child-key", serialized, StringComparison.Ordinal);
        Assert.Contains(
            inspection.StructureItems,
            item => item.ChildNames.Contains("<dynamic-key>"));
    }

    [Fact]
    public void GetInspectionDiagnostics_reports_leveldb_file_groups_without_file_content()
    {
        var levelDbRoot = Path.Combine(_tempRoot, "DingTalk", "IndexedDB", "messages.leveldb");
        Directory.CreateDirectory(levelDbRoot);
        File.WriteAllText(Path.Combine(levelDbRoot, "CURRENT"), "secret-current-value");
        File.WriteAllText(Path.Combine(levelDbRoot, "000001.ldb"), "secret-leveldb-value");
        File.WriteAllText(Path.Combine(levelDbRoot, "000002.log"), "secret-leveldb-log");
        var provider = new LocalStructuredSourceDiagnosticsProvider(
            rootSource: () => new[] { _tempRoot },
            environmentVariableSource: static _ => null);

        var diagnostics = provider.GetInspectionDiagnostics(candidateLimit: 10, itemLimit: 10);

        var inspection = Assert.Single(diagnostics.Inspections);
        Assert.Equal(LocalStructuredSourceInspectionStatus.Inspected, inspection.Status);
        var item = Assert.Single(inspection.StructureItems);
        Assert.Equal(LocalStructuredSourceStructureKind.LevelDbFileGroup, item.Kind);
        Assert.Contains(item.ChildNames, name => name.StartsWith(".ldb:", StringComparison.Ordinal));
        Assert.Contains(item.ChildNames, name => name.StartsWith(".log:", StringComparison.Ordinal));
        var serialized = JsonSerializer.Serialize(diagnostics);
        Assert.DoesNotContain("secret-current-value", serialized, StringComparison.Ordinal);
        Assert.DoesNotContain("secret-leveldb-value", serialized, StringComparison.Ordinal);
        Assert.DoesNotContain("secret-leveldb-log", serialized, StringComparison.Ordinal);
    }

    [Fact]
    public void GetInspectionDiagnostics_skips_logs_and_media_because_their_content_can_be_messages()
    {
        var dingTalkRoot = Path.Combine(_tempRoot, "DingTalk");
        Directory.CreateDirectory(dingTalkRoot);
        File.WriteAllText(Path.Combine(dingTalkRoot, "app.log"), "secret-log-message");
        File.WriteAllBytes(Path.Combine(dingTalkRoot, "thumb.png"), new byte[] { 1, 2, 3 });
        var provider = new LocalStructuredSourceDiagnosticsProvider(
            rootSource: () => new[] { _tempRoot },
            environmentVariableSource: static _ => null);

        var diagnostics = provider.GetInspectionDiagnostics(candidateLimit: 10, itemLimit: 10);

        Assert.All(diagnostics.Inspections, inspection =>
            Assert.Equal(LocalStructuredSourceInspectionStatus.Skipped, inspection.Status));
        Assert.DoesNotContain("secret-log-message", JsonSerializer.Serialize(diagnostics), StringComparison.Ordinal);
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempRoot))
        {
            Directory.Delete(_tempRoot, recursive: true);
        }
    }
}
