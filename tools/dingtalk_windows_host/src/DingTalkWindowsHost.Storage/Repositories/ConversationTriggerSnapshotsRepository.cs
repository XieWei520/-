using System.Security.Cryptography;
using System.Text;
using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Storage.Db;
using Microsoft.Data.Sqlite;

namespace DingTalkWindowsHost.Storage.Repositories;

public sealed class ConversationTriggerSnapshotsRepository
{
    private readonly SqliteDatabase _database;

    public ConversationTriggerSnapshotsRepository(SqliteDatabase database)
    {
        ArgumentNullException.ThrowIfNull(database);
        _database = database;
    }

    public async Task<ConversationTriggerSnapshot?> AddIfChangedAsync(
        UiaConversationDiagnosticsResult diagnostics,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(diagnostics);

        if (diagnostics.Conversations.Count == 0)
        {
            return null;
        }

        var snapshot = BuildSnapshot(diagnostics);
        var latestHash = await GetLatestContentHashAsync(cancellationToken);
        if (string.Equals(latestHash, snapshot.ContentHash, StringComparison.Ordinal))
        {
            return null;
        }

        await InsertAsync(snapshot, cancellationToken);
        return snapshot;
    }

    public async Task<IReadOnlyList<ConversationTriggerSnapshot>> ListRecentAsync(
        int limit,
        CancellationToken cancellationToken)
    {
        var boundedLimit = Math.Clamp(limit, 1, 500);
        var connection = await _database.OpenConnectionAsync(cancellationToken);
        await using var disposable = _database.UsesSharedConnection ? null : connection;
        await using var command = connection.CreateCommand();
        command.CommandText = """
SELECT
  snapshot_id,
  observed_at,
  readiness,
  conversation_count,
  unread_count,
  selected_conversation_name,
  first_unread_conversation_name,
  content_hash,
  summary
FROM conversation_trigger_snapshots
ORDER BY observed_at DESC, snapshot_id DESC
LIMIT $limit;
""";
        command.Parameters.AddWithValue("$limit", boundedLimit);

        var snapshots = new List<ConversationTriggerSnapshot>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            snapshots.Add(new ConversationTriggerSnapshot(
                SnapshotId: reader.GetString(0),
                ObservedAt: DateTimeOffset.Parse(reader.GetString(1)),
                Readiness: Enum.Parse<ConversationReadiness>(reader.GetString(2)),
                ConversationCount: reader.GetInt32(3),
                UnreadCount: reader.GetInt32(4),
                SelectedConversationName: reader.GetString(5),
                FirstUnreadConversationName: reader.GetString(6),
                ContentHash: reader.GetString(7),
                Summary: reader.GetString(8)));
        }

        return snapshots;
    }

    private async Task<string?> GetLatestContentHashAsync(CancellationToken cancellationToken)
    {
        var connection = await _database.OpenConnectionAsync(cancellationToken);
        await using var disposable = _database.UsesSharedConnection ? null : connection;
        await using var command = connection.CreateCommand();
        command.CommandText = """
SELECT content_hash
FROM conversation_trigger_snapshots
ORDER BY observed_at DESC, snapshot_id DESC
LIMIT 1;
""";
        var value = await command.ExecuteScalarAsync(cancellationToken);
        return value as string;
    }

    private async Task InsertAsync(
        ConversationTriggerSnapshot snapshot,
        CancellationToken cancellationToken)
    {
        var connection = await _database.OpenConnectionAsync(cancellationToken);
        await using var disposable = _database.UsesSharedConnection ? null : connection;
        await using var command = connection.CreateCommand();
        command.CommandText = """
INSERT INTO conversation_trigger_snapshots (
  snapshot_id,
  observed_at,
  readiness,
  conversation_count,
  unread_count,
  selected_conversation_name,
  first_unread_conversation_name,
  content_hash,
  summary
) VALUES (
  $snapshot_id,
  $observed_at,
  $readiness,
  $conversation_count,
  $unread_count,
  $selected_conversation_name,
  $first_unread_conversation_name,
  $content_hash,
  $summary
);
""";
        AddSnapshotParameters(command, snapshot);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static ConversationTriggerSnapshot BuildSnapshot(
        UiaConversationDiagnosticsResult diagnostics)
    {
        var readiness = ConversationReadinessEvaluator.Evaluate(diagnostics);
        var selectedConversation = diagnostics.Conversations.FirstOrDefault(static conversation => conversation.IsSelected);
        var firstUnreadConversation = diagnostics.Conversations.FirstOrDefault(static conversation => conversation.HasUnreadHint);
        var contentHash = BuildContentHash(diagnostics, readiness);
        var summary = BuildSummary(diagnostics, readiness);
        return new ConversationTriggerSnapshot(
            SnapshotId: "trigger-" + diagnostics.ObservedAt.ToUniversalTime().Ticks + "-" + contentHash[..12],
            ObservedAt: diagnostics.ObservedAt,
            Readiness: readiness,
            ConversationCount: diagnostics.Conversations.Count,
            UnreadCount: diagnostics.Conversations.Count(static conversation => conversation.HasUnreadHint),
            SelectedConversationName: selectedConversation?.Name ?? string.Empty,
            FirstUnreadConversationName: firstUnreadConversation?.Name ?? string.Empty,
            ContentHash: contentHash,
            Summary: summary);
    }

    private static string BuildContentHash(
        UiaConversationDiagnosticsResult diagnostics,
        ConversationReadiness readiness)
    {
        var builder = new StringBuilder();
        builder.Append(readiness);
        foreach (var conversation in diagnostics.Conversations)
        {
            builder.Append('|');
            builder.Append(conversation.AutomationId);
            builder.Append(':');
            builder.Append(conversation.Name);
            builder.Append(':');
            builder.Append(conversation.IsSelected ? '1' : '0');
            builder.Append(':');
            builder.Append(conversation.HasUnreadHint ? '1' : '0');
        }

        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(builder.ToString()));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }

    private static string BuildSummary(
        UiaConversationDiagnosticsResult diagnostics,
        ConversationReadiness readiness)
    {
        var unreadCount = diagnostics.Conversations.Count(static conversation => conversation.HasUnreadHint);
        var selectedConversation = diagnostics.Conversations.FirstOrDefault(static conversation => conversation.IsSelected);
        var firstUnreadConversation = diagnostics.Conversations.FirstOrDefault(static conversation => conversation.HasUnreadHint);
        return "readiness="
            + readiness
            + " conversations="
            + diagnostics.Conversations.Count
            + " unread="
            + unreadCount
            + " selected='"
            + (selectedConversation?.Name ?? string.Empty)
            + "' firstUnread='"
            + (firstUnreadConversation?.Name ?? string.Empty)
            + "'";
    }

    private static void AddSnapshotParameters(
        SqliteCommand command,
        ConversationTriggerSnapshot snapshot)
    {
        command.Parameters.AddWithValue("$snapshot_id", snapshot.SnapshotId);
        command.Parameters.AddWithValue("$observed_at", snapshot.ObservedAt.ToUniversalTime().ToString("O"));
        command.Parameters.AddWithValue("$readiness", snapshot.Readiness.ToString());
        command.Parameters.AddWithValue("$conversation_count", snapshot.ConversationCount);
        command.Parameters.AddWithValue("$unread_count", snapshot.UnreadCount);
        command.Parameters.AddWithValue("$selected_conversation_name", snapshot.SelectedConversationName);
        command.Parameters.AddWithValue("$first_unread_conversation_name", snapshot.FirstUnreadConversationName);
        command.Parameters.AddWithValue("$content_hash", snapshot.ContentHash);
        command.Parameters.AddWithValue("$summary", snapshot.Summary);
    }
}
