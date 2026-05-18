using DingTalkWindowsHost.Automation.Capture;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class ClipboardMessageTextExtractorTests
{
    [Fact]
    public void TryExtractLatest_returns_last_meaningful_line()
    {
        var result = ClipboardMessageTextExtractor.TryExtractLatest(
            "09:30\r\nAlice\r\nold message\r\n09:31\r\nBob\r\nlatest message",
            "sentinel");

        Assert.Equal("latest message", result);
    }

    [Fact]
    public void TryExtractLatest_accepts_short_copied_messages()
    {
        var result = ClipboardMessageTextExtractor.TryExtractLatest("ok", "sentinel");

        Assert.Equal("ok", result);
    }

    [Fact]
    public void TryExtractLatest_rejects_unchanged_sentinel()
    {
        var result = ClipboardMessageTextExtractor.TryExtractLatest("sentinel", "sentinel");

        Assert.Null(result);
    }

    [Theory]
    [InlineData("")]
    [InlineData("Enter/Alt+S send, Ctrl+Enter newline")]
    [InlineData("DingTalk")]
    [InlineData("09:31")]
    public void TryExtractLatest_rejects_non_message_clipboard_text(string clipboardText)
    {
        var result = ClipboardMessageTextExtractor.TryExtractLatest(clipboardText, "sentinel");

        Assert.Null(result);
    }
}
