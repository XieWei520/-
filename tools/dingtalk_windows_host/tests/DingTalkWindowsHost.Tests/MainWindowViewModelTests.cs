using DingTalkWindowsHost.App.ViewModels;
using DingTalkWindowsHost.Automation.WindowHost;
using DingTalkWindowsHost.Contracts.Models;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class MainWindowViewModelTests
{
    [Theory]
    [InlineData(ConversationReadiness.BlockedByDialog, true)]
    [InlineData(ConversationReadiness.BlockedByOverlay, true)]
    [InlineData(ConversationReadiness.LoginRequired, true)]
    [InlineData(ConversationReadiness.DiagnosticsError, true)]
    [InlineData(ConversationReadiness.NoConversationList, true)]
    [InlineData(ConversationReadiness.ConversationListVisible, false)]
    [InlineData(ConversationReadiness.Ready, false)]
    public void ShouldPauseCapture_only_blocks_non_chat_ready_states(
        ConversationReadiness readiness,
        bool expected)
    {
        Assert.Equal(expected, MainWindowViewModel.ShouldPauseCapture(readiness));
    }

    [Theory]
    [InlineData(false, false)]
    [InlineData(true, true)]
    public void ShouldQueueScreenshotFallback_only_when_ocr_is_explicitly_enabled(
        bool ocrEnabled,
        bool expected)
    {
        Assert.Equal(expected, MainWindowViewModel.ShouldQueueScreenshotFallback(ocrEnabled));
    }

    [Theory]
    [InlineData(false, 1024, 720, true)]
    [InlineData(true, 1024, 720, false)]
    [InlineData(false, 0, 720, false)]
    [InlineData(false, 1024, 0, false)]
    public void ShouldUseHostSurface_only_when_window_is_visible_and_has_size(
        bool isMinimized,
        int width,
        int height,
        bool expected)
    {
        Assert.Equal(expected, MainWindowViewModel.ShouldUseHostSurface(isMinimized, width, height));
    }

    [Fact]
    public void ShouldAttemptCapture_blocks_capture_while_host_surface_is_paused()
    {
        var now = DateTimeOffset.UtcNow;

        var result = MainWindowViewModel.ShouldAttemptCapture(
            hostSurfacePaused: true,
            shellState: WindowSupervisorShellState.Attached,
            currentHwnd: new IntPtr(0x1234),
            now,
            lastCaptureAttemptAt: now - TimeSpan.FromSeconds(10),
            pollInterval: TimeSpan.FromSeconds(2));

        Assert.False(result);
    }

    [Fact]
    public void ShouldAttemptCapture_allows_attached_visible_surface_after_poll_interval()
    {
        var now = DateTimeOffset.UtcNow;

        var result = MainWindowViewModel.ShouldAttemptCapture(
            hostSurfacePaused: false,
            shellState: WindowSupervisorShellState.Attached,
            currentHwnd: new IntPtr(0x1234),
            now,
            lastCaptureAttemptAt: now - TimeSpan.FromSeconds(10),
            pollInterval: TimeSpan.FromSeconds(2));

        Assert.True(result);
    }
}
