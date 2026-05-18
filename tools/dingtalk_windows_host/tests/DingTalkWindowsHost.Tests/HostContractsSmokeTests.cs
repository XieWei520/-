using DingTalkWindowsHost.Contracts.Models;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class HostContractsSmokeTests
{
    [Fact]
    public void DingTalkObservedEvent_can_be_constructed()
    {
        var observedAt = new DateTimeOffset(2026, 5, 15, 0, 0, 0, TimeSpan.Zero);

        var observedEvent = new DingTalkObservedEvent(
            EventId: "evt-001",
            SourceConversationId: "conv-001",
            SourceConversationName: "Operations",
            EmbeddedSourceName: "Feed",
            SenderName: "Bot",
            ObservedAt: observedAt,
            Text: "hello",
            LocalImagePath: "C:\\images\\capture.png",
            CaptureSource: CaptureSource.ChatAreaScreenshotOcr,
            ContentHash: "hash-001");

        Assert.Equal("evt-001", observedEvent.EventId);
        Assert.Equal(CaptureSource.ChatAreaScreenshotOcr, observedEvent.CaptureSource);
        Assert.Equal(observedAt, observedEvent.ObservedAt);
    }
}
