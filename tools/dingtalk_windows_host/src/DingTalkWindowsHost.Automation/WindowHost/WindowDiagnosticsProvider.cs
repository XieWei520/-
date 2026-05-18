using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Contracts.Services;

namespace DingTalkWindowsHost.Automation.WindowHost;

public sealed class WindowDiagnosticsProvider : IWindowDiagnosticsProvider
{
    private readonly DingTalkWindowLocator _locator;
    private readonly Func<IntPtr> _hostedWindowHandle;

    public WindowDiagnosticsProvider(DingTalkWindowLocator locator)
        : this(locator, static () => IntPtr.Zero)
    {
    }

    public WindowDiagnosticsProvider(DingTalkWindowLocator locator, Func<IntPtr> hostedWindowHandle)
    {
        ArgumentNullException.ThrowIfNull(locator);
        ArgumentNullException.ThrowIfNull(hostedWindowHandle);

        _locator = locator;
        _hostedWindowHandle = hostedWindowHandle;
    }

    public IReadOnlyList<string> GetCandidateSummary(int limit)
    {
        var candidates = _locator.GetWindowCandidates();
        var selected = _locator.ChooseMainWindow(candidates);
        var summary = FormatCandidateSummaries(candidates, selected, limit).ToList();

        summary.Insert(0, selected is null
            ? "selected=none"
            : "selected=" + FormatHandle(selected.Handle));
        return summary;
    }

    public WindowCandidateDiagnosticsResult GetCandidateDiagnostics(int limit)
    {
        var candidates = _locator.GetWindowCandidates();
        var selected = _locator.ChooseMainWindow(candidates);
        var hostedHandle = _hostedWindowHandle();
        var visibleCandidates = candidates.Count(static candidate => candidate.IsVisible);
        var hiddenWorkspaceCandidates = candidates.Count(IsHiddenWorkspaceCandidate);
        var blockingDialogCandidates = candidates.Count(IsBlockingDialogCandidate);
        var health = Classify(candidates, selected, hostedHandle, hiddenWorkspaceCandidates, blockingDialogCandidates);
        var summaries = FormatCandidateSummaries(candidates, selected, limit).ToList();
        var allCandidateDiagnostics = candidates
            .Select(candidate => BuildCandidateDiagnostic(candidate, selected))
            .ToList();
        var rejectionReasonCounts = allCandidateDiagnostics
            .GroupBy(static candidate => candidate.RejectionReason)
            .ToDictionary(static group => group.Key, static group => group.Count());
        var candidateDiagnostics = allCandidateDiagnostics
            .OrderBy(GetCandidateDiagnosticRank)
            .ThenByDescending(candidate => candidate.Width * candidate.Height)
            .ThenBy(candidate => candidate.ZOrder)
            .Take(Math.Max(0, limit))
            .ToList();
        summaries.Insert(0, selected is null
            ? "selected=none"
            : "selected=" + FormatHandle(selected.Handle));

        return new WindowCandidateDiagnosticsResult(
            ObservedAt: DateTimeOffset.UtcNow,
            Health: health,
            SelectedHwnd: hostedHandle != IntPtr.Zero
                ? FormatHandle(hostedHandle)
                : selected is null
                    ? string.Empty
                    : FormatHandle(selected.Handle),
            Recommendation: BuildRecommendation(health),
            TotalDingTalkCandidates: candidates.Count,
            VisibleCandidates: visibleCandidates,
            HiddenWorkspaceCandidates: hiddenWorkspaceCandidates,
            BlockingDialogCandidates: blockingDialogCandidates,
            RawSummaries: summaries,
            RejectionReasonCounts: rejectionReasonCounts,
            Candidates: candidateDiagnostics);
    }

    private static IEnumerable<string> FormatCandidateSummaries(
        IReadOnlyList<WindowCandidate> candidates,
        WindowCandidate? selected,
        int limit)
    {
        return candidates
            .Take(Math.Max(0, limit))
            .Select(candidate =>
                "hwnd="
                + FormatHandle(candidate.Handle)
                + " selected="
                + (selected?.Handle == candidate.Handle).ToString()
                + " title='"
                + candidate.Title
                + "' class='"
                + candidate.ClassName
                + "' process='"
                + candidate.ProcessName
                + "' visible="
                + candidate.IsVisible
                + " enabled="
                + candidate.IsEnabled
                + " top="
                + candidate.IsTopLevel
                + " tool="
                + candidate.IsToolWindow
                + " size="
                + candidate.Width
                + "x"
                + candidate.Height);
    }

    private static WindowCandidateHealth Classify(
        IReadOnlyList<WindowCandidate> candidates,
        WindowCandidate? selected,
        IntPtr hostedHandle,
        int hiddenWorkspaceCandidates,
        int blockingDialogCandidates)
    {
        if (selected is null && hostedHandle != IntPtr.Zero)
        {
            return WindowCandidateHealth.HostedCandidate;
        }

        if (candidates.Count == 0)
        {
            return WindowCandidateHealth.NoDingTalkProcess;
        }

        if (blockingDialogCandidates > 0)
        {
            return WindowCandidateHealth.BlockedByDialog;
        }

        if (hostedHandle != IntPtr.Zero)
        {
            return WindowCandidateHealth.HostedCandidate;
        }

        if (selected is not null && IsHiddenWorkspaceCandidate(selected) && hiddenWorkspaceCandidates == candidates.Count)
        {
            return WindowCandidateHealth.HiddenWorkspaceOnly;
        }

        if (selected is not null && !selected.IsTopLevel)
        {
            return WindowCandidateHealth.HostedCandidate;
        }

        return selected is null
            ? WindowCandidateHealth.NoEligibleWindow
            : WindowCandidateHealth.Ready;
    }

    private static string BuildRecommendation(WindowCandidateHealth health)
    {
        return health switch
        {
            WindowCandidateHealth.Ready => "Ready: a DingTalk window candidate is available for hosting.",
            WindowCandidateHealth.NoDingTalkProcess =>
                "Launch DingTalk, sign in, and keep the Windows session unlocked before starting the host.",
            WindowCandidateHealth.NoEligibleWindow =>
                "DingTalk candidates exist but none are eligible; restore the main window or restart DingTalk.",
            WindowCandidateHealth.HiddenWorkspaceOnly =>
                "Only a hidden workspace candidate is available; use Reattach once, then restart DingTalk if it stays hidden.",
            WindowCandidateHealth.BlockedByDialog =>
                "A DingTalk dialog appears to be blocking the main window; close restart/update/login dialogs before capture.",
            WindowCandidateHealth.HostedCandidate =>
                "A hosted child candidate is selected; keep the current attachment unless capture diagnostics fail.",
            _ => "Inspect window candidates and restart DingTalk if the host cannot attach.",
        };
    }

    private static WindowCandidateDiagnostic BuildCandidateDiagnostic(
        WindowCandidate candidate,
        WindowCandidate? selected)
    {
        var isSelected = selected?.Handle == candidate.Handle;
        var rejectionReason = isSelected
            ? WindowCandidateRejectionReason.None
            : GetRejectionReason(candidate);

        var decision = isSelected
            ? WindowCandidateAttachmentDecision.Selected
            : rejectionReason == WindowCandidateRejectionReason.None
                ? WindowCandidateAttachmentDecision.Candidate
                : WindowCandidateAttachmentDecision.Rejected;

        return new WindowCandidateDiagnostic(
            Hwnd: FormatHandle(candidate.Handle),
            IsSelected: isSelected,
            Decision: decision,
            RejectionReason: rejectionReason,
            Title: candidate.Title,
            ClassName: candidate.ClassName,
            ProcessName: candidate.ProcessName,
            IsVisible: candidate.IsVisible,
            IsEnabled: candidate.IsEnabled,
            IsTopLevel: candidate.IsTopLevel,
            IsToolWindow: candidate.IsToolWindow,
            Width: candidate.Width,
            Height: candidate.Height,
            ZOrder: candidate.ZOrder);
    }

    private static int GetCandidateDiagnosticRank(WindowCandidateDiagnostic candidate)
    {
        if (candidate.IsSelected)
        {
            return 0;
        }

        if (candidate.Decision == WindowCandidateAttachmentDecision.Candidate)
        {
            return 1;
        }

        if (candidate.IsVisible && !candidate.IsToolWindow)
        {
            return 2;
        }

        if (!candidate.IsToolWindow)
        {
            return 3;
        }

        return 4;
    }

    private static WindowCandidateRejectionReason GetRejectionReason(WindowCandidate candidate)
    {
        if (candidate.Handle == IntPtr.Zero)
        {
            return WindowCandidateRejectionReason.ZeroHandle;
        }

        if (!candidate.IsEnabled)
        {
            return WindowCandidateRejectionReason.Disabled;
        }

        if (DingTalkTransientOverlayClassifier.IsTransientOverlay(candidate))
        {
            return WindowCandidateRejectionReason.TransientOverlay;
        }

        if (IsHiddenWorkspaceCandidate(candidate))
        {
            return WindowCandidateRejectionReason.None;
        }

        if (candidate.IsToolWindow)
        {
            return WindowCandidateRejectionReason.ToolWindow;
        }

        if ((candidate.Width < 320 || candidate.Height < 240) && !IsVisibleDingTalkMainQtFrame(candidate))
        {
            return WindowCandidateRejectionReason.TooSmall;
        }

        if (!candidate.IsVisible)
        {
            return WindowCandidateRejectionReason.Hidden;
        }

        if (!candidate.IsTopLevel && !IsKnownChatChildCandidate(candidate))
        {
            return WindowCandidateRejectionReason.NotTopLevel;
        }

        return IsSupportedCandidateShape(candidate)
            ? WindowCandidateRejectionReason.None
            : WindowCandidateRejectionReason.UnsupportedClass;
    }

    private static bool IsKnownChatChildCandidate(WindowCandidate candidate)
    {
        return string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
            && !candidate.IsTopLevel
            && (string.Equals(candidate.ClassName, "DingChatWnd", StringComparison.OrdinalIgnoreCase)
                || string.Equals(candidate.ClassName, "CefBrowserWindow", StringComparison.OrdinalIgnoreCase)
                || string.Equals(candidate.ClassName, "Chrome_WidgetWin_1", StringComparison.OrdinalIgnoreCase)
                || (string.Equals(candidate.Title, "DTIMChatModule", StringComparison.OrdinalIgnoreCase)
                    && string.Equals(candidate.ClassName, "Qt51511QWindowIcon", StringComparison.OrdinalIgnoreCase)));
    }

    private static bool IsSupportedCandidateShape(WindowCandidate candidate)
    {
        if (string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
            && (string.Equals(candidate.ClassName, "Chrome_WidgetWin_0", StringComparison.OrdinalIgnoreCase)
                || string.Equals(candidate.ClassName, "StandardFrame_DingTalk", StringComparison.OrdinalIgnoreCase)
                || IsVisibleDingTalkMainQtFrame(candidate)
                || IsDingTalkChatWindow(candidate)
                || IsKnownChatChildCandidate(candidate)))
        {
            return true;
        }

        return candidate.IsTopLevel
            && candidate.IsVisible
            && !string.IsNullOrWhiteSpace(candidate.Title);
    }

    private static bool IsHiddenWorkspaceCandidate(WindowCandidate candidate)
    {
        return string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
            && string.Equals(candidate.ClassName, "Qt51511QWindowIcon", StringComparison.OrdinalIgnoreCase)
            && !candidate.IsVisible
            && candidate.IsEnabled
            && candidate.IsTopLevel
            && candidate.Width >= 320
            && candidate.Height >= 240
            && (string.Equals(candidate.Title, "DingTalk", StringComparison.OrdinalIgnoreCase)
                || string.Equals(candidate.Title, "\u9489\u9489", StringComparison.OrdinalIgnoreCase));
    }

    private static bool IsVisibleDingTalkMainQtFrame(WindowCandidate candidate)
    {
        return string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
            && string.Equals(candidate.ClassName, "Qt51511QWindowIcon", StringComparison.OrdinalIgnoreCase)
            && candidate.IsVisible
            && candidate.IsEnabled
            && candidate.IsTopLevel
            && !candidate.IsToolWindow
            && (candidate.Width >= 320
                && candidate.Height >= 240
                || (candidate.Width == 0
                    && candidate.Height == 0
                    && string.Equals(candidate.Title, "\u9489\u9489", StringComparison.OrdinalIgnoreCase)))
            && (string.Equals(candidate.Title, "\u9489\u9489", StringComparison.OrdinalIgnoreCase)
                || string.Equals(candidate.Title, "DingTalk", StringComparison.OrdinalIgnoreCase));
    }

    private static bool IsDingTalkChatWindow(WindowCandidate candidate)
    {
        return string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
            && string.Equals(candidate.ClassName, "DingChatWnd", StringComparison.OrdinalIgnoreCase)
            && candidate.IsVisible
            && candidate.IsEnabled;
    }

    private static bool IsBlockingDialogCandidate(WindowCandidate candidate)
    {
        if (!candidate.IsVisible || !candidate.IsEnabled || candidate.IsToolWindow)
        {
            return false;
        }

        return string.Equals(candidate.ClassName, "MsgBox", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "OperationTaskDlg", StringComparison.OrdinalIgnoreCase)
            || candidate.Title.Contains("restart", StringComparison.OrdinalIgnoreCase)
            || candidate.Title.Contains("\u91cd\u542f", StringComparison.OrdinalIgnoreCase)
            || candidate.Title.Contains("upgrade", StringComparison.OrdinalIgnoreCase)
            || candidate.Title.Contains("\u5347\u7ea7", StringComparison.OrdinalIgnoreCase);
    }

    private static string FormatHandle(IntPtr handle)
    {
        return "0x" + handle.ToInt64().ToString("X");
    }

    private static string FormatHostedHandle(IntPtr hostedHandle)
    {
        return hostedHandle == IntPtr.Zero ? string.Empty : FormatHandle(hostedHandle);
    }
}
