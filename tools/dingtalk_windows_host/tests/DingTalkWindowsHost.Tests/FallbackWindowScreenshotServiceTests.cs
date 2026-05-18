using DingTalkWindowsHost.Automation.Capture;
using DingTalkWindowsHost.Automation.WindowHost;
using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Contracts.Services;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class FallbackWindowScreenshotServiceTests
{
    [Fact]
    public async Task CaptureChatAreaAsync_uses_content_candidate_when_current_window_capture_fails()
    {
        var inner = new RecordingScreenshotService(
            successHandle: new IntPtr(0x200),
            result: CreateScreenshotResult());
        var service = new FallbackWindowScreenshotService(
            inner,
            new DingTalkWindowLocator(static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x100),
                    Title: "\u9489\u9489",
                    ClassName: "StandardFrame_DingTalk",
                    IsVisible: true,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 896,
                    Height: 612,
                    ZOrder: 0,
                    ProcessName: "DingTalk"),
                new WindowCandidate(
                    Handle: new IntPtr(0x200),
                    Title: string.Empty,
                    ClassName: "CefBrowserWindow",
                    IsVisible: false,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 800,
                    Height: 600,
                    ZOrder: 1,
                    ProcessName: "DingTalk"),
            }));

        var result = await service.CaptureChatAreaAsync(new IntPtr(0x100), CancellationToken.None);

        Assert.NotNull(result);
        Assert.Equal("capture.png", result!.LocalImagePath);
        Assert.Equal(new[] { new IntPtr(0x100), new IntPtr(0x200) }, inner.ChatAreaAttempts);
    }

    [Fact]
    public void BuildFallbackCandidates_prefers_content_windows_and_rejects_transient_overlays()
    {
        var current = new IntPtr(0x100);
        var fallbackCandidates = FallbackWindowScreenshotService.BuildFallbackCandidates(
                desktopCandidates: new[]
                {
                    new WindowCandidate(
                        Handle: new IntPtr(0x200),
                        Title: "DingTalk",
                        ClassName: "Qt51511QWindowIcon",
                        IsVisible: false,
                        IsEnabled: true,
                        IsTopLevel: true,
                        IsToolWindow: false,
                        Width: 818,
                        Height: 647,
                        ZOrder: 2,
                        ProcessName: "DingTalk"),
                    new WindowCandidate(
                        Handle: new IntPtr(0x300),
                        Title: "DingTalk",
                        ClassName: "DTIMChatAtRoleWndView",
                        IsVisible: false,
                        IsEnabled: true,
                        IsTopLevel: true,
                        IsToolWindow: false,
                        Width: 818,
                        Height: 647,
                        ZOrder: 0,
                        ProcessName: "DingTalk"),
                },
                descendantCandidates: new[]
                {
                    new WindowCandidate(
                        Handle: new IntPtr(0x400),
                        Title: "DTIMContentModule",
                        ClassName: "Qt51511QWindowIcon",
                        IsVisible: false,
                        IsEnabled: true,
                        IsTopLevel: false,
                        IsToolWindow: false,
                        Width: 896,
                        Height: 612,
                        ZOrder: 1,
                        ProcessName: "DingTalk"),
                    new WindowCandidate(
                        Handle: new IntPtr(0x500),
                        Title: string.Empty,
                        ClassName: "CefBrowserWindow",
                        IsVisible: false,
                        IsEnabled: true,
                        IsTopLevel: false,
                        IsToolWindow: false,
                        Width: 800,
                        Height: 600,
                        ZOrder: 3,
                        ProcessName: "DingTalk"),
                },
                currentWindowHandle: current)
            .Select(static candidate => candidate.Handle)
            .ToArray();

        Assert.Equal(new[] { new IntPtr(0x400), new IntPtr(0x500) }, fallbackCandidates);
    }

    private static WindowScreenshotResult CreateScreenshotResult()
    {
        return new WindowScreenshotResult(
            LocalImagePath: "capture.png",
            Sha256: "sha",
            Width: 800,
            Height: 600,
            BytesWritten: 42,
            CapturedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"));
    }

    private sealed class RecordingScreenshotService : IWindowScreenshotService
    {
        private readonly WindowScreenshotResult _result;
        private readonly IntPtr _successHandle;

        public RecordingScreenshotService(IntPtr successHandle, WindowScreenshotResult result)
        {
            _successHandle = successHandle;
            _result = result;
        }

        public List<IntPtr> ChatAreaAttempts { get; } = new();

        public Task<WindowScreenshotResult?> CaptureAsync(
            IntPtr windowHandle,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(windowHandle == _successHandle ? _result : null);
        }

        public Task<WindowScreenshotResult?> CaptureChatAreaAsync(
            IntPtr windowHandle,
            CancellationToken cancellationToken)
        {
            ChatAreaAttempts.Add(windowHandle);
            return CaptureAsync(windowHandle, cancellationToken);
        }
    }
}
