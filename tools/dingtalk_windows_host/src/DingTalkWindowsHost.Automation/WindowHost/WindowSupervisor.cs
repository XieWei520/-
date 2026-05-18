using System;

namespace DingTalkWindowsHost.Automation.WindowHost;

public enum WindowSupervisorShellState
{
    Stopped,
    AwaitingHostSurface,
    AwaitingWindow,
    Attached,
    Faulted,
}

public enum WindowSupervisorAction
{
    None,
    Attached,
    Reattached,
    Resized,
    Detached,
    RelaunchRequired,
    Faulted,
}

public sealed record WindowSupervisorSnapshot(
    WindowSupervisorShellState ShellState,
    WindowSupervisorAction LastAction,
    IntPtr CurrentHwnd,
    DateTimeOffset LastEventAt,
    string Message);

public sealed class WindowSupervisor
{
    private readonly IWindowEmbedder _embedder;
    private readonly DingTalkWindowLocator _locator;
    private bool _forceReattach;
    private bool _previousAttachmentRestoreAttempted;
    private bool _runningRequested;
    private WindowSupervisorSnapshot _lastSnapshot = new(
        WindowSupervisorShellState.Stopped,
        WindowSupervisorAction.None,
        IntPtr.Zero,
        DateTimeOffset.MinValue,
        "Host shell is idle.");

    public WindowSupervisor(DingTalkWindowLocator locator, IWindowEmbedder embedder)
    {
        ArgumentNullException.ThrowIfNull(locator);
        ArgumentNullException.ThrowIfNull(embedder);

        _locator = locator;
        _embedder = embedder;
    }

    public WindowSupervisorSnapshot LastSnapshot => _lastSnapshot;

    public void RequestStart()
    {
        _runningRequested = true;
        _previousAttachmentRestoreAttempted = false;
    }

    public void RequestStop()
    {
        _runningRequested = false;
        _forceReattach = false;
        _previousAttachmentRestoreAttempted = false;
    }

    public void RequestReload()
    {
        _runningRequested = true;
        _forceReattach = true;
        _previousAttachmentRestoreAttempted = false;
    }

    public void RequestReattach()
    {
        _runningRequested = true;
        _forceReattach = true;
        _previousAttachmentRestoreAttempted = false;
    }

    public WindowSupervisorSnapshot Tick(IntPtr hostHandle, HostSurfaceBounds bounds)
    {
        try
        {
            var normalizedBounds = bounds.Normalize();

            if (!_runningRequested)
            {
                if (_embedder.CurrentState is not null)
                {
                    try
                    {
                        _embedder.Detach();
                    }
                    catch (Exception ex)
                    {
                        return Publish(
                            WindowSupervisorShellState.Stopped,
                            WindowSupervisorAction.Detached,
                            IntPtr.Zero,
                            "Host shell stopped. Detach failed: " + ex.Message);
                    }

                    return Publish(
                        WindowSupervisorShellState.Stopped,
                        WindowSupervisorAction.Detached,
                        IntPtr.Zero,
                        "Host shell stopped and detached.");
                }

                return Publish(
                    WindowSupervisorShellState.Stopped,
                    WindowSupervisorAction.None,
                    IntPtr.Zero,
                    "Host shell is idle.");
            }

            if (hostHandle == IntPtr.Zero)
            {
                return Publish(
                    WindowSupervisorShellState.AwaitingHostSurface,
                    WindowSupervisorAction.None,
                    IntPtr.Zero,
                    "Host surface is not ready yet.");
            }

            var restoredPreviousAttachment = TryRestorePreviousAttachmentOnce();

            var candidates = _locator.GetWindowCandidates();
            var selectedWindow = _locator.ChooseMainWindow(candidates);
            if (!_forceReattach
                && _embedder.CurrentState is not null
                && _embedder.IsAttachedTo(_embedder.CurrentState.ChildHandle, hostHandle)
                && !ShouldSwitchAttachment(
                    _embedder.CurrentState.ChildHandle,
                    selectedWindow,
                    candidates,
                    restoredPreviousAttachment))
            {
                _embedder.EnsureAttachment(
                    _embedder.CurrentState.ChildHandle,
                    hostHandle,
                    normalizedBounds);
                return Publish(
                    WindowSupervisorShellState.Attached,
                    WindowSupervisorAction.None,
                    _embedder.CurrentState.ChildHandle,
                    "Keeping hosted candidate "
                        + FormatHandle(_embedder.CurrentState.ChildHandle)
                        + ".");
            }

            if (selectedWindow is null)
            {
                if (_embedder.CurrentState is not null
                    && _embedder.IsAttachedTo(_embedder.CurrentState.ChildHandle, hostHandle))
                {
                    _embedder.EnsureAttachment(
                        _embedder.CurrentState.ChildHandle,
                        hostHandle,
                        normalizedBounds);
                    return Publish(
                        WindowSupervisorShellState.Attached,
                        WindowSupervisorAction.None,
                        _embedder.CurrentState.ChildHandle,
                        "Keeping hosted candidate "
                            + FormatHandle(_embedder.CurrentState.ChildHandle)
                            + " after reparenting hid it from desktop enumeration.");
                }

                if (_embedder.CurrentState is not null)
                {
                    _embedder.Detach();
                }

                var action = _lastSnapshot.ShellState == WindowSupervisorShellState.AwaitingWindow
                    ? WindowSupervisorAction.None
                    : WindowSupervisorAction.RelaunchRequired;

                return Publish(
                    WindowSupervisorShellState.AwaitingWindow,
                    action,
                    IntPtr.Zero,
                    "No eligible DingTalk window was found. Relaunch is still external.");
            }

            var hadCurrentAttachment = _embedder.CurrentState is not null;
            var attachmentRequiresReset = _forceReattach
                || !_embedder.IsAttachedTo(selectedWindow.Handle, hostHandle);
            var sizeRequiresUpdate = _embedder.CurrentState is null
                || _embedder.CurrentState.Bounds != normalizedBounds;

            WindowSupervisorAction actionTaken;

            if (attachmentRequiresReset)
            {
                _embedder.Attach(selectedWindow.Handle, hostHandle, normalizedBounds);
                actionTaken = hadCurrentAttachment || _forceReattach
                    ? WindowSupervisorAction.Reattached
                    : WindowSupervisorAction.Attached;
            }
            else if (sizeRequiresUpdate)
            {
                _embedder.Resize(normalizedBounds);
                actionTaken = WindowSupervisorAction.Resized;
            }
            else
            {
                _embedder.EnsureAttachment(selectedWindow.Handle, hostHandle, normalizedBounds);
                actionTaken = WindowSupervisorAction.None;
            }

            _forceReattach = false;

            return Publish(
                WindowSupervisorShellState.Attached,
                actionTaken,
                selectedWindow.Handle,
                "Hosting candidate " + FormatHandle(selectedWindow.Handle) + ".");
        }
        catch (Exception ex)
        {
            var candidates = SafeDescribeCandidates();
            return Publish(
                WindowSupervisorShellState.Faulted,
                WindowSupervisorAction.Faulted,
                IntPtr.Zero,
                "Supervisor fault: " + ex.Message + candidates);
        }
    }

    private string SafeDescribeCandidates()
    {
        try
        {
            var selected = _locator.ChooseMainWindow(_locator.GetWindowCandidates());
            return selected is null
                ? " Candidate=none."
                : " Candidate="
                    + FormatHandle(selected.Handle)
                    + " title='"
                    + selected.Title
                    + "' class='"
                    + selected.ClassName
                    + "' process='"
                    + selected.ProcessName
                    + "' size="
                    + selected.Width
                    + "x"
                    + selected.Height
                    + ".";
        }
        catch (Exception describeError)
        {
            return " CandidateDescribeFailed=" + describeError.Message;
        }
    }

    private bool TryRestorePreviousAttachmentOnce()
    {
        if (_previousAttachmentRestoreAttempted)
        {
            return false;
        }

        _previousAttachmentRestoreAttempted = true;
        return _embedder.TryRestorePreviousAttachment();
    }

    private static bool ShouldSwitchAttachment(
        IntPtr currentHandle,
        WindowCandidate? selectedWindow,
        IReadOnlyList<WindowCandidate> candidates,
        bool restoredPreviousAttachment)
    {
        if (selectedWindow is null
            || selectedWindow.Handle == currentHandle
            || !HasUsableAttachmentSize(selectedWindow))
        {
            return false;
        }

        var currentCandidate = candidates.FirstOrDefault(candidate => candidate.Handle == currentHandle);
        if (currentCandidate is null)
        {
            return selectedWindow.IsVisible || restoredPreviousAttachment;
        }

        if (currentCandidate is not null
            && IsChromiumContainer(currentCandidate)
            && IsDingChatWindow(selectedWindow))
        {
            return true;
        }

        return selectedWindow.IsVisible;
    }

    private static bool HasUsableAttachmentSize(WindowCandidate candidate)
    {
        return candidate.Width >= 320 && candidate.Height >= 240
            || IsTopLevelDingChatWindow(candidate);
    }

    private static bool IsDingChatWindow(WindowCandidate candidate)
    {
        return string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
            && string.Equals(candidate.ClassName, "DingChatWnd", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsTopLevelDingChatWindow(WindowCandidate candidate)
    {
        return IsDingChatWindow(candidate)
            && candidate.IsTopLevel
            && candidate.IsVisible
            && candidate.IsEnabled
            && !candidate.IsToolWindow;
    }

    private static bool IsChromiumContainer(WindowCandidate candidate)
    {
        return string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
            && (string.Equals(candidate.ClassName, "CefBrowserWindow", StringComparison.OrdinalIgnoreCase)
                || string.Equals(candidate.ClassName, "Chrome_WidgetWin_1", StringComparison.OrdinalIgnoreCase)
                || string.Equals(candidate.ClassName, "Chrome_RenderWidgetHostHWND", StringComparison.OrdinalIgnoreCase));
    }

    private WindowSupervisorSnapshot Publish(
        WindowSupervisorShellState shellState,
        WindowSupervisorAction action,
        IntPtr currentHwnd,
        string message)
    {
        var snapshot = new WindowSupervisorSnapshot(
            ShellState: shellState,
            LastAction: action,
            CurrentHwnd: currentHwnd,
            LastEventAt: _lastSnapshot.LastEventAt,
            Message: message);

        var shouldAdvanceEventTime = action != WindowSupervisorAction.None
            || _lastSnapshot.ShellState != shellState
            || _lastSnapshot.CurrentHwnd != currentHwnd
            || !string.Equals(_lastSnapshot.Message, message, StringComparison.Ordinal);

        if (shouldAdvanceEventTime)
        {
            snapshot = snapshot with { LastEventAt = DateTimeOffset.UtcNow };
        }

        _lastSnapshot = snapshot;
        return snapshot;
    }

    private static string FormatHandle(IntPtr handle)
    {
        return "0x" + handle.ToInt64().ToString("X");
    }
}
