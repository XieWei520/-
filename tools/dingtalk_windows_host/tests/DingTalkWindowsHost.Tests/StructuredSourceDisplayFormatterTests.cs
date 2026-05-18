using DingTalkWindowsHost.App.ViewModels;
using DingTalkWindowsHost.Contracts.Models;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class StructuredSourceDisplayFormatterTests
{
    [Fact]
    public void FormatSummary_renders_recommendation_and_signal_statuses()
    {
        var result = new StructuredSourceProbeResult(
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
            Recommendation: "Prioritize Browser DevTools metadata/DOM probing.",
            Signals: new[]
            {
                new StructuredSourceProbeSignal(
                    StructuredSourceKind.BrowserDevTools,
                    StructuredSourceStatus.Candidate,
                    EstimatedLatencyMs: 150,
                    Evidence: "DevTools-like loopback candidate detected on port=9222.",
                    NextAction: "Verify target ownership."),
                new StructuredSourceProbeSignal(
                    StructuredSourceKind.ScreenshotOcr,
                    StructuredSourceStatus.FallbackOnly,
                    EstimatedLatencyMs: 0,
                    Evidence: "OCR is disabled and remains fallback-only.",
                    NextAction: "Only enable cropped OCR if structured sources fail."),
            });

        var summary = StructuredSourceDisplayFormatter.FormatSummary(result);

        Assert.Contains("Recommendation: Prioritize Browser DevTools metadata/DOM probing.", summary);
        Assert.Contains("BrowserDevTools: Candidate (~150ms)", summary);
        Assert.Contains("ScreenshotOcr: FallbackOnly", summary);
        Assert.Contains("port=9222", summary);
    }

    [Fact]
    public void FormatSummary_redacts_long_evidence_to_keep_the_sidebar_readable()
    {
        var result = new StructuredSourceProbeResult(
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
            Recommendation: "Use structured sources before OCR.",
            Signals: new[]
            {
                new StructuredSourceProbeSignal(
                    StructuredSourceKind.EmbeddedChromium,
                    StructuredSourceStatus.Candidate,
                    EstimatedLatencyMs: 200,
                    Evidence: new string('x', 200),
                    NextAction: "Probe DevTools."),
            });

        var summary = StructuredSourceDisplayFormatter.FormatSummary(result);

        Assert.True(summary.Length < 260);
        Assert.Contains("...", summary);
    }

    [Fact]
    public void FormatConversationDiagnostics_highlights_blocking_dialogs_and_conversations()
    {
        var result = new UiaConversationDiagnosticsResult(
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
            Conversations: new[]
            {
                new UiaConversationItem(
                    AutomationId: "conv-a",
                    Name: "客户群A 2条未读",
                    IsSelected: false,
                    HasUnreadHint: true),
            },
            BlockingDialogs: new[]
            {
                new UiaBlockingDialog(
                    Title: string.Empty,
                    Message: "为了确保您可以体验完整功能，请重启应用程序。",
                    ClassName: "MsgBox"),
            },
            Recommendation: "Resolve blocking dialog before capture.");

        var summary = StructuredSourceDisplayFormatter.FormatConversationDiagnostics(result);

        Assert.Contains("Readiness: BlockedByDialog", summary);
        Assert.Contains("Blocking dialogs: 1", summary);
        Assert.Contains("MsgBox", summary);
        Assert.Contains("Conversations: 1", summary);
        Assert.Contains("客户群A", summary);
        Assert.Contains("unread", summary);
    }

    [Fact]
    public void FormatConversationDiagnostics_reports_when_no_conversation_list_is_visible()
    {
        var result = new UiaConversationDiagnosticsResult(
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
            Conversations: Array.Empty<UiaConversationItem>(),
            BlockingDialogs: Array.Empty<UiaBlockingDialog>(),
            Recommendation: "Conversation list was not exposed through UIA for this window.");

        var summary = StructuredSourceDisplayFormatter.FormatConversationDiagnostics(result);

        Assert.Contains("Conversations: 0", summary);
        Assert.Contains("not exposed", summary);
    }

    [Fact]
    public void FormatWindowDiagnostics_renders_health_counts_and_recommendation()
    {
        var result = new WindowCandidateDiagnosticsResult(
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
            Health: WindowCandidateHealth.HiddenWorkspaceOnly,
            SelectedHwnd: "0x811",
            Recommendation: "Only hidden workspace candidates are available; use Reattach or restart DingTalk.",
            TotalDingTalkCandidates: 2,
            VisibleCandidates: 0,
            HiddenWorkspaceCandidates: 1,
            BlockingDialogCandidates: 0,
            RawSummaries: new[]
            {
                "selected=0x811",
                "hwnd=0x811 selected=True title='DingTalk' class='Qt51511QWindowIcon'",
            },
            RejectionReasonCounts: new Dictionary<WindowCandidateRejectionReason, int>
            {
                [WindowCandidateRejectionReason.None] = 1,
            },
            Candidates: new[]
            {
                new WindowCandidateDiagnostic(
                    Hwnd: "0x811",
                    IsSelected: true,
                    Decision: WindowCandidateAttachmentDecision.Selected,
                    RejectionReason: WindowCandidateRejectionReason.None,
                    Title: "DingTalk",
                    ClassName: "Qt51511QWindowIcon",
                    ProcessName: "DingTalk",
                    IsVisible: false,
                    IsEnabled: true,
                    IsTopLevel: true,
                    IsToolWindow: false,
                    Width: 818,
                    Height: 647,
                    ZOrder: 1),
            });

        var summary = StructuredSourceDisplayFormatter.FormatWindowDiagnostics(result);

        Assert.Contains("Window: HiddenWorkspaceOnly", summary);
        Assert.Contains("Selected: 0x811", summary);
        Assert.Contains("visible=0", summary);
        Assert.Contains("hidden=1", summary);
        Assert.Contains("Reattach", summary);
    }

    [Fact]
    public void FormatWindowDiagnostics_renders_candidate_decision_reasons()
    {
        var result = new WindowCandidateDiagnosticsResult(
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
            Health: WindowCandidateHealth.NoEligibleWindow,
            SelectedHwnd: string.Empty,
            Recommendation: "DingTalk candidates exist but none are eligible.",
            TotalDingTalkCandidates: 2,
            VisibleCandidates: 1,
            HiddenWorkspaceCandidates: 0,
            BlockingDialogCandidates: 0,
            RawSummaries: Array.Empty<string>(),
            RejectionReasonCounts: new Dictionary<WindowCandidateRejectionReason, int>
            {
                [WindowCandidateRejectionReason.ToolWindow] = 1,
                [WindowCandidateRejectionReason.TooSmall] = 1,
            },
            Candidates: new[]
            {
                new WindowCandidateDiagnostic(
                    Hwnd: "0x851",
                    IsSelected: false,
                    Decision: WindowCandidateAttachmentDecision.Rejected,
                    RejectionReason: WindowCandidateRejectionReason.ToolWindow,
                    Title: "Form",
                    ClassName: "Qt51511QWindowIcon",
                    ProcessName: "DingTalk",
                    IsVisible: false,
                    IsEnabled: true,
                    IsTopLevel: true,
                    IsToolWindow: true,
                    Width: 300,
                    Height: 450,
                    ZOrder: 1),
                new WindowCandidateDiagnostic(
                    Hwnd: "0x852",
                    IsSelected: false,
                    Decision: WindowCandidateAttachmentDecision.Rejected,
                    RejectionReason: WindowCandidateRejectionReason.TooSmall,
                    Title: "\u9489\u9489",
                    ClassName: "DingTalkMini",
                    ProcessName: "DingTalk",
                    IsVisible: true,
                    IsEnabled: true,
                    IsTopLevel: true,
                    IsToolWindow: false,
                    Width: 120,
                    Height: 80,
                    ZOrder: 2),
            });

        var summary = StructuredSourceDisplayFormatter.FormatWindowDiagnostics(result);

        Assert.Contains("0x851 Rejected/ToolWindow", summary);
        Assert.Contains("0x852 Rejected/TooSmall", summary);
        Assert.Contains("Reasons: ToolWindow=1 TooSmall=1", summary);
    }

    [Fact]
    public void FormatLauncherDiagnostics_renders_readiness_and_recommendation()
    {
        var result = new DingTalkLauncherDiagnosticsResult(
            Readiness: DingTalkLauncherReadiness.NotFound,
            IsConfigured: true,
            PathExists: false,
            RemoteDebuggingPort: 0,
            RendererAccessibilityEnabled: false,
            LauncherPath: @"E:\Apply\DingDing\DingtalkLauncher.exe",
            Recommendation: "Configured launcher path does not exist.",
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"));

        var summary = StructuredSourceDisplayFormatter.FormatLauncherDiagnostics(result);

        Assert.Contains("Launcher: NotFound", summary);
        Assert.Contains("configured=True", summary);
        Assert.Contains("exists=False", summary);
        Assert.Contains("does not exist", summary);
    }

    [Fact]
    public void FormatLauncherDiagnostics_renders_remote_debugging_port_when_configured()
    {
        var result = new DingTalkLauncherDiagnosticsResult(
            Readiness: DingTalkLauncherReadiness.Ready,
            IsConfigured: true,
            PathExists: true,
            RemoteDebuggingPort: 9222,
            RendererAccessibilityEnabled: false,
            LauncherPath: @"E:\Apply\DingDing\DingtalkLauncher.exe",
            Recommendation: "Remote debugging launch is explicitly configured.",
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"));

        var summary = StructuredSourceDisplayFormatter.FormatLauncherDiagnostics(result);

        Assert.Contains("remoteDebug=9222", summary);
    }

    [Fact]
    public void FormatLauncherDiagnostics_renders_renderer_accessibility_when_configured()
    {
        var result = new DingTalkLauncherDiagnosticsResult(
            Readiness: DingTalkLauncherReadiness.Ready,
            IsConfigured: true,
            PathExists: true,
            RemoteDebuggingPort: 0,
            RendererAccessibilityEnabled: true,
            LauncherPath: @"E:\Apply\DingDing\DingtalkLauncher.exe",
            Recommendation: "Renderer accessibility is explicitly configured.",
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"));

        var summary = StructuredSourceDisplayFormatter.FormatLauncherDiagnostics(result);

        Assert.Contains("rendererA11y=true", summary);
        Assert.Contains("Renderer accessibility", summary);
    }
}
