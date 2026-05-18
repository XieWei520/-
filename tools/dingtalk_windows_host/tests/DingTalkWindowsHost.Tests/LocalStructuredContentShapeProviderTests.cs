using System.Text.Json;
using DingTalkWindowsHost.Automation.StructuredSources;
using DingTalkWindowsHost.Contracts.Models;
using Microsoft.Data.Sqlite;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class LocalStructuredContentShapeProviderTests : IDisposable
{
    private readonly string _tempRoot;

    public LocalStructuredContentShapeProviderTests()
    {
        _tempRoot = Path.Combine(Path.GetTempPath(), "dingtalk-local-content-shape-tests-" + Guid.NewGuid());
        Directory.CreateDirectory(_tempRoot);
    }

    [Fact]
    public void GetContentShapeDiagnostics_reports_sqlite_message_shape_without_values()
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
                    conversation_id TEXT,
                    sender_name TEXT,
                    body_text TEXT,
                    created_at TEXT
                );
                INSERT INTO messages (conversation_id, sender_name, body_text, created_at)
                VALUES
                    ('secret-conversation-value', 'secret-sender-value', 'secret-message-body-one', '2026-05-15T10:00:00Z'),
                    ('secret-conversation-value', 'secret-sender-value', 'secret-message-body-two', '2026-05-15T10:01:00Z');
                """;
            command.ExecuteNonQuery();
        }
        SqliteConnection.ClearAllPools();
        var provider = new LocalStructuredSourceDiagnosticsProvider(
            rootSource: () => new[] { _tempRoot },
            environmentVariableSource: static _ => null);

        var diagnostics = provider.GetContentShapeDiagnostics(
            candidateLimit: 10,
            itemLimit: 10,
            sampleLimit: 3);

        var shape = Assert.Single(diagnostics.Shapes);
        Assert.Equal(LocalStructuredContentShapeStatus.Candidate, shape.Status);
        var table = Assert.Single(shape.Tables);
        Assert.Equal("messages", table.Name);
        Assert.Equal(2, table.RowCount);
        Assert.Contains(table.Fields, field => field.Role == LocalStructuredContentFieldRole.Conversation);
        Assert.Contains(table.Fields, field => field.Role == LocalStructuredContentFieldRole.Sender);
        Assert.Contains(table.Fields, field => field.Role == LocalStructuredContentFieldRole.Text);
        Assert.Contains(table.Fields, field => field.Role == LocalStructuredContentFieldRole.Timestamp);
        Assert.Contains(
            table.Fields,
            field => field.Role == LocalStructuredContentFieldRole.Text
                && field.SampleValueHashes.Count > 0
                && field.SampleValueHashes.All(static hash => hash.Length == 64));

        var serialized = JsonSerializer.Serialize(diagnostics);
        Assert.DoesNotContain("secret-conversation-value", serialized, StringComparison.Ordinal);
        Assert.DoesNotContain("secret-sender-value", serialized, StringComparison.Ordinal);
        Assert.DoesNotContain("secret-message-body-one", serialized, StringComparison.Ordinal);
        Assert.DoesNotContain("secret-message-body-two", serialized, StringComparison.Ordinal);
    }

    [Fact]
    public void GetContentShapeDiagnostics_reports_locked_sqlite_message_shape_from_snapshot_without_values()
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
                    conversation_id TEXT,
                    sender_name TEXT,
                    body_text TEXT,
                    created_at TEXT
                );
                INSERT INTO messages (conversation_id, sender_name, body_text, created_at)
                VALUES ('secret-locked-conversation', 'secret-locked-sender', 'secret-locked-message', '2026-05-16T10:00:00Z');
                """;
            command.ExecuteNonQuery();
        }
        SqliteConnection.ClearAllPools();

        var provider = new LocalStructuredSourceDiagnosticsProvider(
            rootSource: () => new[] { _tempRoot },
            environmentVariableSource: static _ => null);

        LocalStructuredContentShapeDiagnosticsResult diagnostics;
        using (var lockConnection = new SqliteConnection(
            "Data Source=" + databasePath + ";Default Timeout=1;Pooling=False"))
        {
            lockConnection.Open();
            using var lockCommand = lockConnection.CreateCommand();
            lockCommand.CommandText = "PRAGMA locking_mode=EXCLUSIVE; BEGIN EXCLUSIVE;";
            lockCommand.ExecuteNonQuery();

            diagnostics = provider.GetContentShapeDiagnostics(
                candidateLimit: 10,
                itemLimit: 10,
                sampleLimit: 3);
        }
        SqliteConnection.ClearAllPools();

        var shape = Assert.Single(diagnostics.Shapes);
        Assert.Equal(LocalStructuredContentShapeStatus.Candidate, shape.Status);
        Assert.Contains("snapshot", shape.Evidence, StringComparison.OrdinalIgnoreCase);
        var table = Assert.Single(shape.Tables);
        Assert.Equal("messages", table.Name);
        Assert.Contains(table.Fields, field => field.Role == LocalStructuredContentFieldRole.Text);
        var serialized = JsonSerializer.Serialize(diagnostics);
        Assert.DoesNotContain("secret-locked-conversation", serialized, StringComparison.Ordinal);
        Assert.DoesNotContain("secret-locked-sender", serialized, StringComparison.Ordinal);
        Assert.DoesNotContain("secret-locked-message", serialized, StringComparison.Ordinal);
    }

    [Fact]
    public void GetContentShapeDiagnostics_reports_nonstandard_sqlite_header_without_opening_rows()
    {
        var dingTalkRoot = Path.Combine(_tempRoot, "DingTalk");
        Directory.CreateDirectory(dingTalkRoot);
        File.WriteAllText(Path.Combine(dingTalkRoot, "dingtalk.db"), "secret-message-body-not-a-sqlite-file");
        var provider = new LocalStructuredSourceDiagnosticsProvider(
            rootSource: () => new[] { _tempRoot },
            environmentVariableSource: static _ => null);

        var diagnostics = provider.GetContentShapeDiagnostics(
            candidateLimit: 10,
            itemLimit: 10,
            sampleLimit: 3);

        var shape = Assert.Single(diagnostics.Shapes);
        Assert.Equal(LocalStructuredContentShapeStatus.NotReadable, shape.Status);
        Assert.Contains("not a standard SQLite database header", shape.Evidence, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("secret-message-body", JsonSerializer.Serialize(diagnostics), StringComparison.Ordinal);
    }

    [Fact]
    public void GetContentShapeDiagnostics_reports_leveldb_keyword_shape_without_values()
    {
        var levelDbRoot = Path.Combine(_tempRoot, "DingTalk", "Local Storage", "leveldb");
        Directory.CreateDirectory(levelDbRoot);
        File.WriteAllText(Path.Combine(levelDbRoot, "CURRENT"), "MANIFEST-000001");
        File.WriteAllText(
            Path.Combine(levelDbRoot, "000001.ldb"),
            "message sender conversation content secret-message-body");
        var provider = new LocalStructuredSourceDiagnosticsProvider(
            rootSource: () => new[] { _tempRoot },
            environmentVariableSource: static _ => null);

        var diagnostics = provider.GetContentShapeDiagnostics(
            candidateLimit: 10,
            itemLimit: 10,
            sampleLimit: 3);

        var shape = Assert.Single(diagnostics.Shapes);
        Assert.Equal(LocalStructuredContentShapeStatus.KeywordOnly, shape.Status);
        Assert.Contains(shape.KeywordHits, hit => hit.Keyword == "message" && hit.Count > 0);
        Assert.DoesNotContain("secret-message-body", JsonSerializer.Serialize(diagnostics), StringComparison.Ordinal);
    }

    [Fact]
    public void GetContentShapeDiagnostics_reports_json_message_shape_without_values()
    {
        var dingTalkRoot = Path.Combine(_tempRoot, "DingTalk");
        Directory.CreateDirectory(dingTalkRoot);
        File.WriteAllText(
            Path.Combine(dingTalkRoot, "message-cache.json"),
            """
            {
              "messages": [
                {
                  "conversation_id": "secret-json-conversation",
                  "sender_name": "secret-json-sender",
                  "body_text": "secret-json-message",
                  "created_at": "2026-05-16T11:00:00Z"
                }
              ]
            }
            """);
        var provider = new LocalStructuredSourceDiagnosticsProvider(
            rootSource: () => new[] { _tempRoot },
            environmentVariableSource: static _ => null);

        var diagnostics = provider.GetContentShapeDiagnostics(
            candidateLimit: 10,
            itemLimit: 10,
            sampleLimit: 3);

        var shape = Assert.Single(diagnostics.Shapes);
        Assert.Equal(LocalStructuredContentShapeStatus.Candidate, shape.Status);
        Assert.Equal(64, shape.PathHash.Length);
        var table = Assert.Single(shape.Tables);
        Assert.Equal("$.messages[]", table.Name);
        Assert.Contains(table.Fields, field => field.Role == LocalStructuredContentFieldRole.Conversation);
        Assert.Contains(table.Fields, field => field.Role == LocalStructuredContentFieldRole.Sender);
        Assert.Contains(table.Fields, field => field.Role == LocalStructuredContentFieldRole.Text);
        Assert.Contains(table.Fields, field => field.Role == LocalStructuredContentFieldRole.Timestamp);
        Assert.All(table.Fields, field =>
        {
            Assert.Equal(0, field.NonEmptySampleCount);
            Assert.Empty(field.SampleValueHashes);
        });

        var serialized = JsonSerializer.Serialize(diagnostics);
        Assert.DoesNotContain("secret-json-conversation", serialized, StringComparison.Ordinal);
        Assert.DoesNotContain("secret-json-sender", serialized, StringComparison.Ordinal);
        Assert.DoesNotContain("secret-json-message", serialized, StringComparison.Ordinal);
        Assert.DoesNotContain(dingTalkRoot, serialized, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void GetContentShapeDiagnostics_does_not_treat_json_feature_flags_as_message_shape()
    {
        var dingTalkRoot = Path.Combine(_tempRoot, "DingTalk");
        Directory.CreateDirectory(dingTalkRoot);
        File.WriteAllText(
            Path.Combine(dingTalkRoot, "feature-flags.json"),
            """
            {
              "flags": {
                "entrance_conversation_enable_k2": true,
                "chat_message_merge_disable": true,
                "message_max_count": 100,
                "common_timeout": 30,
                "sender_display_style": "secret-feature-flag-value"
              }
            }
            """);
        var provider = new LocalStructuredSourceDiagnosticsProvider(
            rootSource: () => new[] { _tempRoot },
            environmentVariableSource: static _ => null);

        var diagnostics = provider.GetContentShapeDiagnostics(
            candidateLimit: 10,
            itemLimit: 10,
            sampleLimit: 3);

        var shape = Assert.Single(diagnostics.Shapes);
        Assert.Equal(LocalStructuredContentShapeStatus.NoMessageShape, shape.Status);
        Assert.Empty(shape.Tables);
        Assert.DoesNotContain("secret-feature-flag-value", JsonSerializer.Serialize(diagnostics), StringComparison.Ordinal);
    }

    [Fact]
    public void GetContentShapeDiagnostics_does_not_treat_timestamp_only_table_as_message_shape()
    {
        var dingTalkRoot = Path.Combine(_tempRoot, "DingTalk");
        Directory.CreateDirectory(dingTalkRoot);
        var databasePath = Path.Combine(dingTalkRoot, "apps.sqlite");
        using (var connection = new SqliteConnection("Data Source=" + databasePath))
        {
            connection.Open();
            using var command = connection.CreateCommand();
            command.CommandText = """
                CREATE TABLE app_install (
                    id INTEGER PRIMARY KEY,
                    updateAppTime TEXT
                );
                INSERT INTO app_install (updateAppTime) VALUES ('2026-05-15T10:00:00Z');
                """;
            command.ExecuteNonQuery();
        }
        SqliteConnection.ClearAllPools();
        var provider = new LocalStructuredSourceDiagnosticsProvider(
            rootSource: () => new[] { _tempRoot },
            environmentVariableSource: static _ => null);

        var diagnostics = provider.GetContentShapeDiagnostics(
            candidateLimit: 10,
            itemLimit: 10,
            sampleLimit: 3);

        var shape = Assert.Single(diagnostics.Shapes);
        Assert.Equal(LocalStructuredContentShapeStatus.NoMessageShape, shape.Status);
        Assert.Empty(Assert.Single(diagnostics.Shapes).Tables);
    }

    [Fact]
    public void GetDiagnostics_classifies_sqlite_wal_candidates_without_content()
    {
        var dingTalkRoot = Path.Combine(_tempRoot, "DingTalk");
        Directory.CreateDirectory(dingTalkRoot);
        File.WriteAllBytes(Path.Combine(dingTalkRoot, "dingtalk.db-wal"), new byte[] { 0x37, 0x7f, 0x06, 0x82 });
        var provider = new LocalStructuredSourceDiagnosticsProvider(
            rootSource: () => new[] { _tempRoot },
            environmentVariableSource: static _ => null);

        var diagnostics = provider.GetDiagnostics(candidateLimit: 10);

        var candidate = Assert.Single(diagnostics.Candidates);
        Assert.Equal(LocalStructuredSourceCandidateKind.SqliteWriteAheadLog, candidate.Kind);
        Assert.DoesNotContain("37 7f", JsonSerializer.Serialize(diagnostics), StringComparison.OrdinalIgnoreCase);
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempRoot))
        {
            Directory.Delete(_tempRoot, recursive: true);
        }
    }
}
