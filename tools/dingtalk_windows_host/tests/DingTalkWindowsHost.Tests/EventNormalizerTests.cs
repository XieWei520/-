using DingTalkWindowsHost.Automation.Capture;
using DingTalkWindowsHost.Contracts.Models;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class EventNormalizerTests
{
    [Fact]
    public void Normalize_creates_stable_uia_text_event()
    {
        var capture = new ExtractedMessage(
            SourceConversationName: "  Alpha Group  ",
            SenderName: "  Alice  ",
            Text: " hello from dingtalk ",
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:03Z"));

        var result = new EventNormalizer().Normalize(capture);

        Assert.NotNull(result);
        Assert.Equal("Alpha Group", result!.SourceConversationName);
        Assert.StartsWith("windows:", result.SourceConversationId, StringComparison.Ordinal);
        Assert.Equal(16, result.SourceConversationId.Length);
        Assert.Equal("Alice", result.SenderName);
        Assert.Equal("hello from dingtalk", result.Text);
        Assert.Equal(CaptureSource.UiaText, result.CaptureSource);
        Assert.EndsWith(result.ContentHash, result.EventId, StringComparison.Ordinal);
    }

    [Fact]
    public void Normalize_keeps_empty_conversation_as_non_forwardable_diagnostic_source()
    {
        var capture = new ExtractedMessage(
            SourceConversationName: string.Empty,
            SenderName: "Alice",
            Text: "hello from dingtalk",
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:03Z"));

        var result = new EventNormalizer().Normalize(capture);

        Assert.NotNull(result);
        Assert.Equal("source:unknown", result!.SourceConversationId);
    }

    [Fact]
    public void Normalize_uses_explicit_source_conversation_id_hint_for_clipboard_probe()
    {
        var capture = new ExtractedMessage(
            SourceConversationName: "(clipboard active chat)",
            SenderName: string.Empty,
            Text: "hello from clipboard",
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:03Z"),
            SourceConversationIdHint: "windows:clipboard-active");

        var result = new EventNormalizer().Normalize(capture);

        Assert.NotNull(result);
        Assert.Equal("windows:clipboard-active", result!.SourceConversationId);
        Assert.Equal(CaptureSource.UiaText, result.CaptureSource);
        Assert.Equal("hello from clipboard", result.Text);
    }

    [Theory]
    [InlineData(CaptureSource.ChatAreaScreenshot)]
    [InlineData(CaptureSource.ChatAreaScreenshotOcr)]
    public void Normalize_keeps_screenshot_fallback_sources_diagnostic(CaptureSource captureSource)
    {
        var capture = new ExtractedMessage(
            SourceConversationName: "DingTalk Screenshot",
            SenderName: "VisualHash",
            Text: "Chat area visual change abc123",
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:03Z"),
            CaptureSource: captureSource);

        var result = new EventNormalizer().Normalize(capture);

        Assert.NotNull(result);
        Assert.Equal("source:dingtalk-screenshot", result!.SourceConversationId);
    }

    [Fact]
    public void Normalize_extracts_embedded_source_marker_from_message_body()
    {
        var capture = new ExtractedMessage(
            SourceConversationName: "Outer Group",
            SenderName: "Relay",
            Text: "[Inner Group] alert body",
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:03Z"));

        var result = new EventNormalizer().Normalize(capture);

        Assert.NotNull(result);
        Assert.Equal("Inner Group", result!.EmbeddedSourceName);
        Assert.Equal("alert body", result.Text);
    }

    [Fact]
    public void Normalize_uses_timestamp_bucket_in_event_id()
    {
        var normalizer = new EventNormalizer();
        var first = normalizer.Normalize(new ExtractedMessage(
            SourceConversationName: "Ops",
            SenderName: "Alice",
            Text: "same",
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:03Z")));
        var second = normalizer.Normalize(new ExtractedMessage(
            SourceConversationName: "Ops",
            SenderName: "Alice",
            Text: "same",
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:55Z")));

        Assert.NotNull(first);
        Assert.NotNull(second);
        Assert.Equal(first!.EventId, second!.EventId);
    }

    [Fact]
    public void Normalize_uses_stable_clipboard_fallback_event_id_across_minutes()
    {
        var normalizer = new EventNormalizer();
        var first = normalizer.Normalize(new ExtractedMessage(
            SourceConversationName: "(clipboard active chat)",
            SenderName: string.Empty,
            Text: "same latest fallback text",
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:03Z"),
            SourceConversationIdHint: "windows:clipboard-active"));
        var second = normalizer.Normalize(new ExtractedMessage(
            SourceConversationName: "(clipboard active chat)",
            SenderName: string.Empty,
            Text: "same latest fallback text",
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:02:03Z"),
            SourceConversationIdHint: "windows:clipboard-active"));

        Assert.NotNull(first);
        Assert.NotNull(second);
        Assert.Equal(first!.EventId, second!.EventId);
    }

    [Theory]
    [InlineData("当前检测出钉钉异常，请点击”确定“ 清理本地缓存尝试修复")]
    [InlineData("钉钉安全模式")]
    [InlineData("Resolve blocking dialog before capture.")]
    [InlineData("login-required: DingTalk is showing the login view; sign in before capture.")]
    public void Normalize_drops_dingtalk_system_blocker_text(string text)
    {
        var capture = new ExtractedMessage(
            SourceConversationName: string.Empty,
            SenderName: string.Empty,
            Text: text,
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:03Z"));

        var result = new EventNormalizer().Normalize(capture);

        Assert.Null(result);
    }
}
