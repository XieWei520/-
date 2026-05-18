using DingTalkWindowsHost.Automation.Capture;
using DingTalkWindowsHost.Automation.WindowHost;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class UiaMessageProbeCoordinatorTests
{
    [Fact]
    public void ProbeLatest_tries_hosted_selected_and_content_descendants_until_message_is_found()
    {
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x100),
                Title: "\u9489\u9489",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1200,
                Height: 800,
                ZOrder: 0,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x200),
                Title: string.Empty,
                ClassName: "DingChatWnd",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: false,
                Width: 900,
                Height: 700,
                ZOrder: 1,
                ProcessName: "DingTalk"),
        };
        var descendants = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x300),
                Title: "DTIMContentModule",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: false,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: false,
                Width: 1,
                Height: 1,
                ZOrder: 2,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x400),
                Title: string.Empty,
                ClassName: "QWindowContainer",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: false,
                Width: 0,
                Height: 0,
                ZOrder: 3,
                ProcessName: "DingTalk"),
        };
        var locator = new DingTalkWindowLocator(() => candidates);
        var probedHandles = new List<IntPtr>();
        var coordinator = new UiaMessageProbeCoordinator(
            locator,
            static () => new IntPtr(0x200),
            handle =>
            {
                probedHandles.Add(handle);
                return handle == new IntPtr(0x300)
                    ? new ExtractedMessage(
                        SourceConversationName: "Alpha",
                        SenderName: "Alice",
                        Text: "hello",
                        ObservedAt: DateTimeOffset.Parse("2026-05-16T10:00:00Z"))
                    : null;
            },
            _ => descendants);

        var result = coordinator.ProbeLatest();

        Assert.NotNull(result);
        Assert.Equal("hello", result!.Text);
        Assert.Equal(
            new[] { new IntPtr(0x200), new IntPtr(0x100), new IntPtr(0x300) },
            probedHandles);
    }

    [Fact]
    public void ProbeLatest_uses_clipboard_probe_after_uia_windows_return_no_message()
    {
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x100),
                Title: "\u9489\u9489",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1200,
                Height: 800,
                ZOrder: 0,
                ProcessName: "DingTalk"),
        };
        var locator = new DingTalkWindowLocator(() => candidates);
        var clipboardProbeCalls = 0;
        var coordinator = new UiaMessageProbeCoordinator(
            locator,
            static () => new IntPtr(0x100),
            _ => null,
            _ => Array.Empty<WindowCandidate>(),
            handle =>
            {
                clipboardProbeCalls++;
                Assert.Equal(new IntPtr(0x100), handle);
                return new ExtractedMessage(
                    SourceConversationName: "(clipboard active chat)",
                    SenderName: string.Empty,
                    Text: "copied latest",
                    ObservedAt: DateTimeOffset.Parse("2026-05-16T10:00:00Z"),
                    SourceConversationIdHint: "windows:clipboard-active");
            });

        var result = coordinator.ProbeLatest();

        Assert.NotNull(result);
        Assert.Equal("copied latest", result!.Text);
        Assert.Equal("windows:clipboard-active", result.SourceConversationIdHint);
        Assert.Equal(1, clipboardProbeCalls);
    }
}
