using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Storage.Db;
using Microsoft.Data.Sqlite;

namespace DingTalkWindowsHost.Storage.Repositories;

public sealed class RawEventsRepository
{
    private readonly SqliteDatabase _database;

    public RawEventsRepository(SqliteDatabase database)
    {
        ArgumentNullException.ThrowIfNull(database);
        _database = database;
    }

    public async Task UpsertAsync(DingTalkObservedEvent observedEvent, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(observedEvent);

        var connection = await _database.OpenConnectionAsync(cancellationToken);
        await using var disposable = _database.UsesSharedConnection ? null : connection;
        await using var command = connection.CreateCommand();
        command.CommandText = """
INSERT INTO raw_events (
  event_id,
  source_conversation_id,
  source_conversation_name,
  embedded_source_name,
  sender_name,
  observed_at,
  text,
  local_image_path,
  capture_source,
  content_hash,
  dedupe_key
) VALUES (
  $event_id,
  $source_conversation_id,
  $source_conversation_name,
  $embedded_source_name,
  $sender_name,
  $observed_at,
  $text,
  $local_image_path,
  $capture_source,
  $content_hash,
  $dedupe_key
)
ON CONFLICT(event_id) DO UPDATE SET
  source_conversation_id = excluded.source_conversation_id,
  source_conversation_name = excluded.source_conversation_name,
  embedded_source_name = excluded.embedded_source_name,
  sender_name = excluded.sender_name,
  observed_at = excluded.observed_at,
  text = excluded.text,
  local_image_path = excluded.local_image_path,
  capture_source = excluded.capture_source,
  content_hash = excluded.content_hash,
  dedupe_key = excluded.dedupe_key;
""";

        AddEventParameters(command, observedEvent);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<DingTalkObservedEvent>> ListRecentAsync(
        int limit,
        CancellationToken cancellationToken)
    {
        return await ListRecentCoreAsync(limit, forwardableOnly: false, cancellationToken);
    }

    public async Task<IReadOnlyList<DingTalkObservedEvent>> ListForwardableRecentAsync(
        int limit,
        CancellationToken cancellationToken)
    {
        return await ListRecentCoreAsync(limit, forwardableOnly: true, cancellationToken);
    }

    private async Task<IReadOnlyList<DingTalkObservedEvent>> ListRecentCoreAsync(
        int limit,
        bool forwardableOnly,
        CancellationToken cancellationToken)
    {
        var boundedLimit = Math.Clamp(limit, 1, 500);
        var connection = await _database.OpenConnectionAsync(cancellationToken);
        await using var disposable = _database.UsesSharedConnection ? null : connection;
        await using var command = connection.CreateCommand();
        command.CommandText = forwardableOnly ? """
SELECT
  event_id,
  source_conversation_id,
  source_conversation_name,
  embedded_source_name,
  sender_name,
  observed_at,
  text,
  local_image_path,
  capture_source,
  content_hash
FROM raw_events
WHERE capture_source = 'UiaText'
  AND trim(source_conversation_id) <> ''
  AND source_conversation_id NOT LIKE 'source:%'
  AND text NOT LIKE '__DINGTALK_HOST_CLIPBOARD_PROBE__%'
ORDER BY observed_at DESC, event_id DESC
LIMIT $limit;
""" : """
SELECT
  event_id,
  source_conversation_id,
  source_conversation_name,
  embedded_source_name,
  sender_name,
  observed_at,
  text,
  local_image_path,
  capture_source,
  content_hash
FROM raw_events
ORDER BY observed_at DESC, event_id DESC
LIMIT $limit;
""";
        command.Parameters.AddWithValue("$limit", boundedLimit);

        var events = new List<DingTalkObservedEvent>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            events.Add(new DingTalkObservedEvent(
                EventId: reader.GetString(0),
                SourceConversationId: reader.GetString(1),
                SourceConversationName: reader.GetString(2),
                EmbeddedSourceName: reader.GetString(3),
                SenderName: reader.GetString(4),
                ObservedAt: DateTimeOffset.Parse(reader.GetString(5)),
                Text: reader.GetString(6),
                LocalImagePath: reader.GetString(7),
                CaptureSource: Enum.Parse<CaptureSource>(reader.GetString(8)),
                ContentHash: reader.GetString(9)));
        }

        return events;
    }

    private static void AddEventParameters(SqliteCommand command, DingTalkObservedEvent observedEvent)
    {
        command.Parameters.AddWithValue("$event_id", observedEvent.EventId);
        command.Parameters.AddWithValue("$source_conversation_id", observedEvent.SourceConversationId);
        command.Parameters.AddWithValue("$source_conversation_name", observedEvent.SourceConversationName);
        command.Parameters.AddWithValue("$embedded_source_name", observedEvent.EmbeddedSourceName);
        command.Parameters.AddWithValue("$sender_name", observedEvent.SenderName);
        command.Parameters.AddWithValue("$observed_at", observedEvent.ObservedAt.ToUniversalTime().ToString("O"));
        command.Parameters.AddWithValue("$text", observedEvent.Text);
        command.Parameters.AddWithValue("$local_image_path", observedEvent.LocalImagePath);
        command.Parameters.AddWithValue("$capture_source", observedEvent.CaptureSource.ToString());
        command.Parameters.AddWithValue("$content_hash", observedEvent.ContentHash);
        command.Parameters.AddWithValue("$dedupe_key", BuildDedupeKey(observedEvent));
    }

    private static string BuildDedupeKey(DingTalkObservedEvent observedEvent)
    {
        var timestampBucket = observedEvent.ObservedAt
            .ToUniversalTime()
            .ToString("yyyyMMddHHmm");
        return string.Join(
            '|',
            observedEvent.SourceConversationId,
            observedEvent.SenderName,
            timestampBucket,
            observedEvent.ContentHash);
    }

}
