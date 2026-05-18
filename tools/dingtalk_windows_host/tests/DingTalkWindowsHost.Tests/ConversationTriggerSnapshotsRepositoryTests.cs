using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Storage.Db;
using DingTalkWindowsHost.Storage.Repositories;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class ConversationTriggerSnapshotsRepositoryTests
{
    [Fact]
    public async Task AddIfChangedAsync_persists_first_visible_conversation_snapshot()
    {
        await using var database = await SqliteDatabase.CreateInMemoryAsync(CancellationToken.None);
        var repository = new ConversationTriggerSnapshotsRepository(database);

        var snapshot = await repository.AddIfChangedAsync(
            CreateDiagnostics(hasUnread: false),
            CancellationToken.None);

        Assert.NotNull(snapshot);
        Assert.Equal(ConversationReadiness.Ready, snapshot!.Readiness);
        Assert.Equal(1, snapshot.ConversationCount);
        Assert.Equal("Alpha Group", snapshot.SelectedConversationName);
        var recent = await repository.ListRecentAsync(10, CancellationToken.None);
        Assert.Single(recent);
    }

    [Fact]
    public async Task AddIfChangedAsync_skips_unchanged_conversation_snapshot()
    {
        await using var database = await SqliteDatabase.CreateInMemoryAsync(CancellationToken.None);
        var repository = new ConversationTriggerSnapshotsRepository(database);

        var first = await repository.AddIfChangedAsync(
            CreateDiagnostics(hasUnread: false, observedAt: "2026-05-15T10:00:00Z"),
            CancellationToken.None);
        var duplicate = await repository.AddIfChangedAsync(
            CreateDiagnostics(hasUnread: false, observedAt: "2026-05-15T10:00:05Z"),
            CancellationToken.None);

        Assert.NotNull(first);
        Assert.Null(duplicate);
        var recent = await repository.ListRecentAsync(10, CancellationToken.None);
        Assert.Single(recent);
    }

    [Fact]
    public async Task AddIfChangedAsync_inserts_when_unread_hint_changes()
    {
        await using var database = await SqliteDatabase.CreateInMemoryAsync(CancellationToken.None);
        var repository = new ConversationTriggerSnapshotsRepository(database);

        await repository.AddIfChangedAsync(
            CreateDiagnostics(hasUnread: false, observedAt: "2026-05-15T10:00:00Z"),
            CancellationToken.None);
        var changed = await repository.AddIfChangedAsync(
            CreateDiagnostics(hasUnread: true, observedAt: "2026-05-15T10:00:05Z"),
            CancellationToken.None);

        Assert.NotNull(changed);
        Assert.Equal(1, changed!.UnreadCount);
        var recent = await repository.ListRecentAsync(10, CancellationToken.None);
        Assert.Equal(2, recent.Count);
    }

    [Fact]
    public async Task AddIfChangedAsync_does_not_persist_when_no_conversation_list_is_visible()
    {
        await using var database = await SqliteDatabase.CreateInMemoryAsync(CancellationToken.None);
        var repository = new ConversationTriggerSnapshotsRepository(database);

        var snapshot = await repository.AddIfChangedAsync(
            new UiaConversationDiagnosticsResult(
                ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
                Conversations: Array.Empty<UiaConversationItem>(),
                BlockingDialogs: Array.Empty<UiaBlockingDialog>(),
                Recommendation: "Conversation list was not exposed."),
            CancellationToken.None);

        Assert.Null(snapshot);
        var recent = await repository.ListRecentAsync(10, CancellationToken.None);
        Assert.Empty(recent);
    }

    private static UiaConversationDiagnosticsResult CreateDiagnostics(
        bool hasUnread,
        string observedAt = "2026-05-15T10:00:00Z")
    {
        return new UiaConversationDiagnosticsResult(
            ObservedAt: DateTimeOffset.Parse(observedAt),
            Conversations: new[]
            {
                new UiaConversationItem(
                    AutomationId: "conv-alpha",
                    Name: "Alpha Group",
                    IsSelected: true,
                    HasUnreadHint: hasUnread),
            },
            BlockingDialogs: Array.Empty<UiaBlockingDialog>(),
            Recommendation: "Use conversation list changes as triggers.");
    }
}
