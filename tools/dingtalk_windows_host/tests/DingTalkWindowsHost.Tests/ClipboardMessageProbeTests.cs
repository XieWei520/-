using System.Drawing;
using DingTalkWindowsHost.Automation.Capture;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class ClipboardMessageProbeTests
{
    [Fact]
    public void TryBuildMessageSurfaceClickPoint_targets_message_history_area()
    {
        var result = ClipboardMessageProbe.TryBuildMessageSurfaceClickPoint(
            new Rectangle(100, 200, 1200, 900),
            out var point);

        Assert.True(result);
        Assert.Equal(new Point(900, 650), point);
    }

    [Theory]
    [InlineData(0, 900)]
    [InlineData(1200, 0)]
    public void TryBuildMessageSurfaceClickPoint_rejects_empty_bounds(int width, int height)
    {
        var result = ClipboardMessageProbe.TryBuildMessageSurfaceClickPoint(
            new Rectangle(100, 200, width, height),
            out var point);

        Assert.False(result);
        Assert.Equal(default, point);
    }

    [Fact]
    public void BuildActivationTargets_includes_target_parent_and_root_without_duplicates()
    {
        var result = ClipboardMessageProbe.BuildActivationTargets(
            new IntPtr(0x100),
            handle => handle == new IntPtr(0x100) ? new IntPtr(0x200) : IntPtr.Zero,
            handle => handle == new IntPtr(0x100) ? new IntPtr(0x300) : handle);

        Assert.Equal(
            new[] { new IntPtr(0x100), new IntPtr(0x200), new IntPtr(0x300) },
            result);
    }

    [Fact]
    public void BuildActivationTargets_skips_zero_and_duplicate_handles()
    {
        var result = ClipboardMessageProbe.BuildActivationTargets(
            new IntPtr(0x100),
            _ => IntPtr.Zero,
            _ => new IntPtr(0x100));

        Assert.Equal(new[] { new IntPtr(0x100) }, result);
    }

    [Fact]
    public void BuildStaThreadFailureError_returns_redacted_exception_metadata()
    {
        var error = ClipboardMessageProbe.BuildStaThreadFailureError(
            new InvalidOperationException("sensitive message"),
            timedOut: false,
            lastStage: "copy-message-surface");

        Assert.Contains("InvalidOperationException", error, StringComparison.Ordinal);
        Assert.Contains("hresult=", error, StringComparison.Ordinal);
        Assert.Contains("copy-message-surface", error, StringComparison.Ordinal);
        Assert.DoesNotContain("sensitive message", error, StringComparison.Ordinal);
    }

    [Fact]
    public void BuildStaThreadFailureError_reports_timeout_stage_without_content()
    {
        var error = ClipboardMessageProbe.BuildStaThreadFailureError(
            failure: null,
            timedOut: true,
            lastStage: "set-sentinel");

        Assert.Equal("clipboard-probe-thread-timeout stage='set-sentinel'", error);
    }

    [Fact]
    public void TryReadUnicodeClipboardText_rejects_empty_handle()
    {
        var result = ClipboardMessageProbe.TryReadUnicodeClipboardTextForTests(
            IntPtr.Zero,
            _ => IntPtr.Zero,
            _ => IntPtr.Zero,
            _ => false);

        Assert.Null(result);
    }

    [Fact]
    public void TryExtractLatest_skips_all_clipboard_probe_sentinel_lines()
    {
        const string currentSentinel = "__DINGTALK_HOST_CLIPBOARD_PROBE__current";
        var clipboardText = string.Join(
            Environment.NewLine,
            "real message",
            "__DINGTALK_HOST_CLIPBOARD_PROBE__previous",
            currentSentinel);

        var extracted = ClipboardMessageTextExtractor.TryExtractLatest(
            clipboardText,
            currentSentinel);

        Assert.Equal("real message", extracted);
    }

    [Theory]
    [InlineData(null, false)]
    [InlineData("", false)]
    [InlineData("original clipboard", true)]
    public void ShouldRestoreClipboardText_rejects_null_or_empty_text(
        string? originalClipboardText,
        bool expected)
    {
        Assert.Equal(
            expected,
            ClipboardMessageProbe.ShouldRestoreClipboardTextForTests(
                originalClipboardText));
    }
}
