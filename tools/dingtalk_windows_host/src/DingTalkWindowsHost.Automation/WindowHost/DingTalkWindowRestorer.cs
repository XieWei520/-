using System.Runtime.InteropServices;
using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Contracts.Services;

namespace DingTalkWindowsHost.Automation.WindowHost;

public sealed class DingTalkWindowRestorer : IDingTalkWindowRestorer
{
    private const int SwRestore = 9;
    private const int SwShow = 5;

    private readonly DingTalkWindowLocator _locator;
    private readonly Func<IntPtr, bool> _restoreWindow;

    public DingTalkWindowRestorer(DingTalkWindowLocator locator)
        : this(locator, RestoreNativeWindow)
    {
    }

    public DingTalkWindowRestorer(DingTalkWindowLocator locator, Func<IntPtr, bool> restoreWindow)
    {
        ArgumentNullException.ThrowIfNull(locator);
        ArgumentNullException.ThrowIfNull(restoreWindow);

        _locator = locator;
        _restoreWindow = restoreWindow;
    }

    public DingTalkWindowRestoreResult Restore()
    {
        var attemptedAt = DateTimeOffset.UtcNow;
        WindowCandidate? candidate;
        try
        {
            candidate = ChooseRestoreCandidate(_locator.GetWindowCandidates());
        }
        catch (Exception ex)
        {
            return Failed(
                targetHwnd: string.Empty,
                message: "Failed to inspect DingTalk window candidates: " + ex.Message,
                attemptedAt);
        }

        if (candidate is null)
        {
            return new DingTalkWindowRestoreResult(
                Status: DingTalkWindowRestoreStatus.NoCandidate,
                TargetHwnd: string.Empty,
                Message: "No non-tool DingTalk window candidate was available to restore.",
                AttemptedAt: attemptedAt);
        }

        var targetHwnd = FormatHandle(candidate.Handle);
        bool restored;
        try
        {
            restored = _restoreWindow(candidate.Handle);
        }
        catch (Exception ex)
        {
            return Failed(
                targetHwnd,
                "Restore/foreground request threw for DingTalk window: " + ex.Message,
                attemptedAt);
        }

        return new DingTalkWindowRestoreResult(
            Status: restored ? DingTalkWindowRestoreStatus.Restored : DingTalkWindowRestoreStatus.Failed,
            TargetHwnd: targetHwnd,
            Message: restored
                ? "Restore/foreground request was sent to DingTalk window."
                : "Restore/foreground request failed for DingTalk window.",
            AttemptedAt: attemptedAt);
    }

    private static WindowCandidate? ChooseRestoreCandidate(IReadOnlyList<WindowCandidate> candidates)
    {
        return candidates
            .Where(static candidate => candidate.Handle != IntPtr.Zero
                && string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
                && candidate.IsEnabled
                && !candidate.IsToolWindow
                && !DingTalkTransientOverlayClassifier.IsTransientOverlay(candidate)
                && IsRestorableDingTalkWindow(candidate))
            .OrderByDescending(static candidate => candidate.IsVisible)
            .ThenByDescending(static candidate => candidate.Width >= 320 && candidate.Height >= 240)
            .ThenByDescending(static candidate => candidate.IsTopLevel)
            .ThenByDescending(static candidate => candidate.Area)
            .ThenBy(static candidate => candidate.ZOrder)
            .FirstOrDefault();
    }

    private static bool IsRestorableDingTalkWindow(WindowCandidate candidate)
    {
        if (string.Equals(candidate.ClassName, "StandardFrame_DingTalk", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        return string.Equals(candidate.ClassName, "Qt51511QWindowIcon", StringComparison.OrdinalIgnoreCase)
            && !IsVisibleSmallTopLevelQtHelperWindow(candidate);
    }

    private static bool IsVisibleSmallTopLevelQtHelperWindow(WindowCandidate candidate)
    {
        return candidate.IsVisible
            && candidate.IsTopLevel
            && !HasUsableVisibleMainQtFrameSize(candidate);
    }

    private static bool HasUsableVisibleMainQtFrameSize(WindowCandidate candidate)
    {
        return candidate.Width >= 320 && candidate.Height >= 240
            || (candidate.Width == 0
                && candidate.Height == 0
                && string.Equals(candidate.Title, "\u9489\u9489", StringComparison.OrdinalIgnoreCase));
    }

    private static bool RestoreNativeWindow(IntPtr handle)
    {
        if (handle == IntPtr.Zero)
        {
            return false;
        }

        _ = ShowWindow(handle, SwRestore);
        _ = ShowWindow(handle, SwShow);
        return SetForegroundWindow(handle);
    }

    private static string FormatHandle(IntPtr handle)
    {
        return "0x" + handle.ToInt64().ToString("X");
    }

    private static DingTalkWindowRestoreResult Failed(
        string targetHwnd,
        string message,
        DateTimeOffset attemptedAt)
    {
        return new DingTalkWindowRestoreResult(
            Status: DingTalkWindowRestoreStatus.Failed,
            TargetHwnd: targetHwnd,
            Message: message,
            AttemptedAt: attemptedAt);
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetForegroundWindow(IntPtr hWnd);
}
