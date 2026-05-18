using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Storage.Db;
using DingTalkWindowsHost.Storage.Repositories;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class RawEventsRepositoryTests
{
    [Fact]
    public async Task UpsertAsync_replaces_duplicate_event_id()
    {
        await using var database = await SqliteDatabase.CreateInMemoryAsync(CancellationToken.None);
        var repository = new RawEventsRepository(database);
        var first = CreateEvent("evt-1", "first");
        var updated = CreateEvent("evt-1", "updated");

        await repository.UpsertAsync(first, CancellationToken.None);
        await repository.UpsertAsync(updated, CancellationToken.None);

        var recent = await repository.ListRecentAsync(10, CancellationToken.None);
        var only = Assert.Single(recent);
        Assert.Equal("updated", only.Text);
    }

    [Fact]
    public async Task ListRecentAsync_orders_newest_first_and_applies_limit()
    {
        await using var database = await SqliteDatabase.CreateInMemoryAsync(CancellationToken.None);
        var repository = new RawEventsRepository(database);

        await repository.UpsertAsync(CreateEvent("evt-1", "old", observedAt: "2026-05-15T10:00:00Z"), CancellationToken.None);
        await repository.UpsertAsync(CreateEvent("evt-2", "new", observedAt: "2026-05-15T10:01:00Z"), CancellationToken.None);

        var recent = await repository.ListRecentAsync(1, CancellationToken.None);

        var only = Assert.Single(recent);
        Assert.Equal("evt-2", only.EventId);
    }

    [Fact]
    public async Task ListForwardableRecentAsync_only_returns_structured_text_events()
    {
        await using var database = await SqliteDatabase.CreateInMemoryAsync(CancellationToken.None);
        var repository = new RawEventsRepository(database);

        await repository.UpsertAsync(
            CreateEvent(
                "evt-visual",
                "Chat area visual change abc123",
                captureSource: CaptureSource.ChatAreaScreenshot,
                senderName: "VisualHash"),
            CancellationToken.None);
        await repository.UpsertAsync(
            CreateEvent(
                "evt-ocr",
                "low confidence OCR body",
                captureSource: CaptureSource.ChatAreaScreenshotOcr,
                senderName: "OCR"),
            CancellationToken.None);
        await repository.UpsertAsync(
            CreateEvent(
                "evt-image",
                "image metadata",
                captureSource: CaptureSource.UiaImageMetadata,
                senderName: "Image"),
            CancellationToken.None);
        await repository.UpsertAsync(
            CreateEvent(
                "evt-uia-diagnostic",
                "diagnostic UIA text",
                sourceConversationId: "source:alpha"),
            CancellationToken.None);
        await repository.UpsertAsync(
            CreateEvent(
                "evt-sentinel",
                "__DINGTALK_HOST_CLIPBOARD_PROBE__abc123",
                sourceConversationId: "windows:clipboard-active"),
            CancellationToken.None);
        await repository.UpsertAsync(
            CreateEvent(
                "evt-text",
                "real message",
                captureSource: CaptureSource.UiaText,
                sourceConversationId: "windows:fb61ccc7"),
            CancellationToken.None);

        var recent = await repository.ListForwardableRecentAsync(10, CancellationToken.None);

        var only = Assert.Single(recent);
        Assert.Equal("evt-text", only.EventId);
        Assert.Equal("real message", only.Text);
        Assert.Equal("windows:fb61ccc7", only.SourceConversationId);
    }

    [Fact]
    public async Task ListForwardableRecentAsync_keeps_distinct_event_ids_with_same_content_hash()
    {
        await using var database = await SqliteDatabase.CreateInMemoryAsync(CancellationToken.None);
        var repository = new RawEventsRepository(database);

        await repository.UpsertAsync(
            CreateEvent(
                "evt-old",
                "same message",
                observedAt: "2026-05-15T10:00:00Z",
                sourceConversationId: "windows:clipboard-active"),
            CancellationToken.None);
        await repository.UpsertAsync(
            CreateEvent(
                "evt-new",
                "same message",
                observedAt: "2026-05-15T10:02:00Z",
                sourceConversationId: "windows:clipboard-active"),
            CancellationToken.None);

        var recent = await repository.ListForwardableRecentAsync(10, CancellationToken.None);

        Assert.Equal(2, recent.Count);
        Assert.Equal("evt-new", recent[0].EventId);
        Assert.Equal("evt-old", recent[1].EventId);
        Assert.All(recent, item => Assert.Equal("same message", item.Text));
    }

    private static DingTalkObservedEvent CreateEvent(
        string eventId,
        string text,
        string observedAt = "2026-05-15T10:00:00Z",
        CaptureSource captureSource = CaptureSource.UiaText,
        string senderName = "Alice",
        string sourceConversationId = "chat-alpha")
    {
        return new DingTalkObservedEvent(
            EventId: eventId,
            SourceConversationId: sourceConversationId,
            SourceConversationName: "Alpha",
            EmbeddedSourceName: string.Empty,
            SenderName: senderName,
            ObservedAt: DateTimeOffset.Parse(observedAt),
            Text: text,
            LocalImagePath: string.Empty,
            CaptureSource: captureSource,
            ContentHash: "hash-" + text);
    }
}
