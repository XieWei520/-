using DingTalkWindowsHost.Automation.Capture;
using DingTalkWindowsHost.Automation.WindowHost;
using DingTalkWindowsHost.Contracts.Models;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class UiaCandidateDiagnosticsProviderTests
{
    [Fact]
    public void ProbeCandidates_probes_hosted_selected_and_visible_chromium_content_candidates()
    {
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x100),
                Title: "\u9489\u9489",
                ClassName: "StandardFrame_DingTalk",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1280,
                Height: 800,
                ZOrder: 0,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x200),
                Title: string.Empty,
                ClassName: "CefBrowserWindow",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: false,
                Width: 1024,
                Height: 713,
                ZOrder: 1,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x300),
                Title: "Tool",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: false,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: true,
                Width: 1024,
                Height: 713,
                ZOrder: 2,
                ProcessName: "DingTalk"),
        };
        var locator = new DingTalkWindowLocator(() => candidates);
        var probedHandles = new List<IntPtr>();
        var provider = new UiaCandidateDiagnosticsProvider(
            locator,
            static () => new IntPtr(0x100),
            (handle, _) =>
            {
                probedHandles.Add(handle);
                return new[] { "node-" + handle.ToInt64().ToString("X") };
            },
            (handle, _) => new UiaConversationDiagnosticsResult(
                ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
                Conversations: handle == new IntPtr(0x200)
                    ? new[]
                    {
                        new UiaConversationItem("conv", "Alpha Group", IsSelected: true, HasUnreadHint: false),
                    }
                    : Array.Empty<UiaConversationItem>(),
                BlockingDialogs: Array.Empty<UiaBlockingDialog>(),
                Recommendation: handle == new IntPtr(0x200)
                    ? "Use conversation list changes as low-latency triggers."
                    : "Conversation list was not exposed through UIA for this window."));

        var result = provider.ProbeCandidates(candidateLimit: 5, snapshotLimit: 3, conversationLimit: 2);

        Assert.Equal("0x100", result.HostedHwnd);
        Assert.Equal("0x100", result.SelectedWindowCandidateHwnd);
        Assert.Equal(new[] { new IntPtr(0x100), new IntPtr(0x200) }, probedHandles);
        Assert.Equal(2, result.Probes.Count);
        Assert.True(result.Probes[0].IsHosted);
        Assert.True(result.Probes[0].IsSelectedWindowCandidate);
        Assert.Equal("0x200", result.Probes[1].Hwnd);
        Assert.False(result.Probes[1].IsSelectedWindowCandidate);
        Assert.Equal(ConversationReadiness.Ready, result.Probes[1].Readiness);
        Assert.Contains("0x200", result.Recommendation, StringComparison.Ordinal);
    }

    [Fact]
    public void ProbeCandidates_probes_hidden_chromium_content_candidates_with_attachable_size()
    {
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x110),
                Title: "\u9489\u9489",
                ClassName: "StandardFrame_DingTalk",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1280,
                Height: 800,
                ZOrder: 0,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x210),
                Title: string.Empty,
                ClassName: "Chrome_RenderWidgetHostHWND",
                IsVisible: false,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: false,
                Width: 800,
                Height: 600,
                ZOrder: 1,
                ProcessName: "DingTalk"),
        };
        var locator = new DingTalkWindowLocator(() => candidates);
        var probedHandles = new List<IntPtr>();
        var provider = new UiaCandidateDiagnosticsProvider(
            locator,
            static () => new IntPtr(0x110),
            (handle, _) =>
            {
                probedHandles.Add(handle);
                return new[] { "node-" + handle.ToInt64().ToString("X") };
            },
            static (_, _) => new UiaConversationDiagnosticsResult(
                ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
                Conversations: Array.Empty<UiaConversationItem>(),
                BlockingDialogs: Array.Empty<UiaBlockingDialog>(),
                Recommendation: "Conversation list was not exposed through UIA for this window."));

        var result = provider.ProbeCandidates(candidateLimit: 5, snapshotLimit: 3, conversationLimit: 2);

        Assert.Equal(new[] { new IntPtr(0x110), new IntPtr(0x210) }, probedHandles);
        Assert.Equal(2, result.Probes.Count);
        Assert.Contains(result.Probes, probe => probe.Hwnd == "0x210");
    }

    [Fact]
    public void ProbeCandidates_probes_visible_zero_sized_dingtalk_qt_main_frame_when_selected()
    {
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x120),
                Title: "\u9489\u9489",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 0,
                Height: 0,
                ZOrder: 0,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x220),
                Title: "ConvTabListView",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: false,
                Width: 296,
                Height: 789,
                ZOrder: 1,
                ProcessName: "DingTalk"),
        };
        var locator = new DingTalkWindowLocator(() => candidates);
        var probedHandles = new List<IntPtr>();
        var provider = new UiaCandidateDiagnosticsProvider(
            locator,
            static () => IntPtr.Zero,
            (handle, _) =>
            {
                probedHandles.Add(handle);
                return new[] { "node-" + handle.ToInt64().ToString("X") };
            },
            static (_, _) => new UiaConversationDiagnosticsResult(
                ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
                Conversations: Array.Empty<UiaConversationItem>(),
                BlockingDialogs: Array.Empty<UiaBlockingDialog>(),
                Recommendation: "Conversation list was not exposed through UIA for this window."));

        var result = provider.ProbeCandidates(candidateLimit: 5, snapshotLimit: 3, conversationLimit: 2);

        Assert.Equal("0x120", result.SelectedWindowCandidateHwnd);
        Assert.Contains(new IntPtr(0x120), probedHandles);
        Assert.Contains(result.Probes, probe => probe.Hwnd == "0x120" && probe.IsSelectedWindowCandidate);
    }

    [Fact]
    public void ProbeCandidates_probes_hosted_descendant_content_windows()
    {
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x130),
                Title: "\u9489\u9489",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 0,
                Height: 0,
                ZOrder: 0,
                ProcessName: "DingTalk"),
        };
        var descendantCandidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x230),
                Title: "DTIMContentModule",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: false,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: false,
                Width: 1,
                Height: 1,
                ZOrder: 1,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x330),
                Title: string.Empty,
                ClassName: "QWindowContainer",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: false,
                Width: 0,
                Height: 0,
                ZOrder: 2,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x430),
                Title: string.Empty,
                ClassName: "DuiShadowWnd",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: true,
                Width: 200,
                Height: 200,
                ZOrder: 3,
                ProcessName: "DingTalk"),
        };
        var locator = new DingTalkWindowLocator(() => candidates);
        var probedHandles = new List<IntPtr>();
        var provider = new UiaCandidateDiagnosticsProvider(
            locator,
            static () => new IntPtr(0x130),
            (handle, _) =>
            {
                probedHandles.Add(handle);
                return new[] { "node-" + handle.ToInt64().ToString("X") };
            },
            static (_, _) => new UiaConversationDiagnosticsResult(
                ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
                Conversations: Array.Empty<UiaConversationItem>(),
                BlockingDialogs: Array.Empty<UiaBlockingDialog>(),
                Recommendation: "Conversation list was not exposed through UIA for this window."),
            _ => descendantCandidates);

        var result = provider.ProbeCandidates(candidateLimit: 5, snapshotLimit: 3, conversationLimit: 2);

        Assert.Contains(new IntPtr(0x230), probedHandles);
        Assert.Contains(new IntPtr(0x330), probedHandles);
        Assert.DoesNotContain(new IntPtr(0x430), probedHandles);
        Assert.Contains(result.Probes, probe => probe.Hwnd == "0x230");
        Assert.Contains(result.Probes, probe => probe.Hwnd == "0x330");
    }

    [Fact]
    public void ProbeCandidates_degrades_individual_candidate_when_uia_probe_fails()
    {
        var locator = new DingTalkWindowLocator(static () => new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x400),
                Title: string.Empty,
                ClassName: "Chrome_WidgetWin_1",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: false,
                Width: 1024,
                Height: 713,
                ZOrder: 1,
                ProcessName: "DingTalk"),
        });
        var provider = new UiaCandidateDiagnosticsProvider(
            locator,
            static () => IntPtr.Zero,
            static (_, _) => throw new InvalidOperationException("snapshot failed"),
            static (_, _) => throw new InvalidOperationException("conversation failed"));

        var result = provider.ProbeCandidates(candidateLimit: 5, snapshotLimit: 3, conversationLimit: 2);

        var probe = Assert.Single(result.Probes);
        Assert.Equal(ConversationReadiness.DiagnosticsError, probe.Readiness);
        Assert.Contains("InvalidOperationException", probe.Error, StringComparison.Ordinal);
        Assert.Empty(probe.NodeSummary);
    }
}
