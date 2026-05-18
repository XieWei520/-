using DingTalkWindowsHost.Api;
using DingTalkWindowsHost.Contracts.Models;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class HostRuntimeStatusTests
{
    [Fact]
    public void UpdateWindowSnapshot_exposes_current_hwnd_and_shell_state()
    {
        var state = new HostRuntimeStatus();
        state.UpdateWindowSnapshot(
            shellState: "Attached",
            currentHwnd: new IntPtr(0x1234),
            lastEventAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
            message: "attached");
        var dto = state.ToDto(captureRunning: true);

        Assert.True(dto.CaptureRunning);
        Assert.Equal("Attached", dto.ShellState);
        Assert.Equal("0x1234", dto.CurrentHwnd);
        Assert.Equal("attached", dto.Message);
    }

    [Fact]
    public void UpdateConversationDiagnostics_reports_blocking_dialog_readiness()
    {
        var state = new HostRuntimeStatus();

        state.UpdateConversationDiagnostics(new UiaConversationDiagnosticsResult(
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
            Conversations: Array.Empty<UiaConversationItem>(),
            BlockingDialogs: new[]
            {
                new UiaBlockingDialog("Update", "Restart required.", "MsgBox"),
            },
            Recommendation: "Resolve blocking dialog before capture."));

        var dto = state.ToDto(captureRunning: true);

        Assert.Equal("BlockedByDialog", dto.ConversationReadiness);
        Assert.Contains("Restart required.", dto.ConversationReadinessMessage, StringComparison.Ordinal);
    }

    [Fact]
    public void UpdateConversationDiagnostics_reports_diagnostics_error_readiness()
    {
        var state = new HostRuntimeStatus();

        state.UpdateConversationDiagnostics(new UiaConversationDiagnosticsResult(
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
            Conversations: Array.Empty<UiaConversationItem>(),
            BlockingDialogs: Array.Empty<UiaBlockingDialog>(),
            Recommendation: "conversation-diagnostics-error type='TimeoutException' message='UIA Timeout'"));

        var dto = state.ToDto(captureRunning: true);

        Assert.Equal("DiagnosticsError", dto.ConversationReadiness);
        Assert.Contains("UIA Timeout", dto.ConversationReadinessMessage, StringComparison.Ordinal);
    }

    [Fact]
    public void UpdateConversationDiagnostics_reports_login_required_readiness()
    {
        var state = new HostRuntimeStatus();

        state.UpdateConversationDiagnostics(new UiaConversationDiagnosticsResult(
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
            Conversations: Array.Empty<UiaConversationItem>(),
            BlockingDialogs: Array.Empty<UiaBlockingDialog>(),
            Recommendation: "login-required: DingTalk is showing the login view; sign in before capture."));

        var dto = state.ToDto(captureRunning: true);

        Assert.Equal("LoginRequired", dto.ConversationReadiness);
        Assert.Contains("sign in", dto.ConversationReadinessMessage, StringComparison.Ordinal);
    }

    [Fact]
    public void UpdateConversationDiagnostics_reports_blocked_by_overlay_readiness()
    {
        var state = new HostRuntimeStatus();

        state.UpdateConversationDiagnostics(new UiaConversationDiagnosticsResult(
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
            Conversations: Array.Empty<UiaConversationItem>(),
            BlockingDialogs: Array.Empty<UiaBlockingDialog>(),
            Recommendation: "blocked-by-overlay: DingTalk search or mask overlay is covering the conversation surface."));

        var dto = state.ToDto(captureRunning: true);

        Assert.Equal("BlockedByOverlay", dto.ConversationReadiness);
        Assert.Contains("overlay", dto.ConversationReadinessMessage, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData(false, 0, "NoConversationList")]
    [InlineData(false, 1, "ConversationListVisible")]
    [InlineData(true, 1, "Ready")]
    public void UpdateConversationDiagnostics_derives_readiness_from_visible_conversations(
        bool selected,
        int conversationCount,
        string expectedReadiness)
    {
        var state = new HostRuntimeStatus();
        var conversations = Enumerable.Range(0, conversationCount)
            .Select(index => new UiaConversationItem(
                AutomationId: "conv-" + index,
                Name: "Alpha " + index,
                IsSelected: selected && index == 0,
                HasUnreadHint: false))
            .ToArray();

        state.UpdateConversationDiagnostics(new UiaConversationDiagnosticsResult(
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
            Conversations: conversations,
            BlockingDialogs: Array.Empty<UiaBlockingDialog>(),
            Recommendation: "Use conversation list changes as triggers."));

        var dto = state.ToDto(captureRunning: true);

        Assert.Equal(expectedReadiness, dto.ConversationReadiness);
    }

    [Fact]
    public void ToDto_reports_ocr_enabled_from_configured_source()
    {
        var state = new HostRuntimeStatus(static () => true);

        var dto = state.ToDto(captureRunning: false);

        Assert.True(dto.OcrEnabled);
    }
}
