using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace DingTalkWindowsHost.Automation.WindowHost;

public readonly record struct HostSurfaceBounds(int Width, int Height)
{
    public HostSurfaceBounds Normalize()
    {
        var width = Width < 1 ? 1 : Width;
        var height = Height < 1 ? 1 : Height;
        return new HostSurfaceBounds(width, height);
    }
}

public sealed record EmbeddedWindowState(
    IntPtr HostHandle,
    IntPtr ChildHandle,
    IntPtr OriginalParentHandle,
    HostSurfaceBounds Bounds,
    DateTimeOffset AttachedAt,
    IntPtr OriginalStyle,
    IntPtr OriginalExStyle);

public sealed class NativeWindowEmbedder : IWindowEmbedder
{
    private const int GwlStyle = -16;
    private const int GwlExStyle = -20;
    private const long WsCaption = 0x00C00000L;
    private const long WsChild = 0x40000000L;
    private const long WsPopup = 0x80000000L;
    private const long WsThickFrame = 0x00040000L;
    private const long WsExAppWindow = 0x00040000L;
    private const long WsExToolWindow = 0x00000080L;
    private const int SwRestore = 9;
    private const int SwShow = 5;
    private const int DpiHostingBehaviorInvalid = -1;
    private const int DpiHostingBehaviorMixed = 1;
    private const uint SwpNoActivate = 0x0010;
    private const uint SwpFrameChanged = 0x0020;
    private const uint SwpNoOwnerZOrder = 0x0200;
    private const uint SwpNoZOrder = 0x0004;
    private const uint SwpShowWindow = 0x0040;

    private readonly WindowAttachmentJournal _journal;

    public NativeWindowEmbedder()
        : this(WindowAttachmentJournal.Disabled)
    {
    }

    public NativeWindowEmbedder(WindowAttachmentJournal journal)
    {
        ArgumentNullException.ThrowIfNull(journal);
        _journal = journal;
    }

    public EmbeddedWindowState? CurrentState { get; private set; }

    public void Attach(IntPtr childHandle, IntPtr hostHandle, HostSurfaceBounds bounds)
    {
        ValidateWindowHandle(childHandle, nameof(childHandle));
        ValidateWindowHandle(hostHandle, nameof(hostHandle));

        var normalizedBounds = bounds.Normalize();

        var originalParentHandle = CurrentState?.ChildHandle == childHandle
            ? CurrentState.OriginalParentHandle
            : GetParent(childHandle);
        var originalStyle = CurrentState?.ChildHandle == childHandle
            ? CurrentState.OriginalStyle
            : GetWindowLongPtr(childHandle, GwlStyle);
        var originalExStyle = CurrentState?.ChildHandle == childHandle
            ? CurrentState.OriginalExStyle
            : GetWindowLongPtr(childHandle, GwlExStyle);

        if (CurrentState is not null && CurrentState.ChildHandle != childHandle)
        {
            RestoreState(CurrentState);
            CurrentState = null;
            _journal.Clear();
        }

        ApplyHostedWindowStyles(childHandle, originalStyle, originalExStyle);
        using (DpiHostingScope.EnableMixedHosting())
        {
            SetParentOrThrow(childHandle, hostHandle);
        }
        ApplyBounds(childHandle, hostHandle, normalizedBounds);

        CurrentState = new EmbeddedWindowState(
            HostHandle: hostHandle,
            ChildHandle: childHandle,
            OriginalParentHandle: originalParentHandle,
            Bounds: normalizedBounds,
            AttachedAt: DateTimeOffset.UtcNow,
            OriginalStyle: originalStyle,
            OriginalExStyle: originalExStyle);
        _journal.Save(CurrentState);
    }

    public void Resize(HostSurfaceBounds bounds)
    {
        if (CurrentState is null)
        {
            return;
        }

        var normalizedBounds = bounds.Normalize();
        ApplyBounds(CurrentState.ChildHandle, CurrentState.HostHandle, normalizedBounds);
        CurrentState = CurrentState with { Bounds = normalizedBounds };
    }

    public void EnsureAttachment(IntPtr childHandle, IntPtr hostHandle, HostSurfaceBounds bounds)
    {
        if (!IsAttachedTo(childHandle, hostHandle))
        {
            Attach(childHandle, hostHandle, bounds);
            return;
        }

        Resize(bounds);
    }

    public bool IsAttachedTo(IntPtr childHandle, IntPtr hostHandle)
    {
        return CurrentState is not null
            && CurrentState.ChildHandle == childHandle
            && CurrentState.HostHandle == hostHandle
            && IsWindow(childHandle)
            && IsWindow(hostHandle);
    }

    public bool TryRestorePreviousAttachment()
    {
        var previousState = _journal.Load();
        if (previousState is null || !IsWindow(previousState.ChildHandle))
        {
            _journal.Clear();
            return false;
        }

        try
        {
            RestoreState(previousState);
            CurrentState = null;
            _journal.Clear();
            return true;
        }
        catch (Win32Exception)
        {
            return false;
        }
    }

    public void Detach()
    {
        if (CurrentState is null)
        {
            return;
        }

        try
        {
            var state = CurrentState;
            var childHandle = state.ChildHandle;

            if (IsWindow(childHandle))
            {
                RestoreState(state);
            }
        }
        finally
        {
            CurrentState = null;
            _journal.Clear();
        }
    }

    private static void RestoreState(EmbeddedWindowState state)
    {
        if (!IsWindow(state.ChildHandle))
        {
            return;
        }

        RestoreWindowStyles(state.ChildHandle, state.OriginalStyle, state.OriginalExStyle);
        SetParentOrThrow(state.ChildHandle, ResolveRestoreParent(state.OriginalParentHandle));
    }

    private static void ApplyBounds(
        IntPtr childHandle,
        IntPtr hostHandle,
        HostSurfaceBounds bounds)
    {
        _ = ShowWindow(childHandle, SwRestore);
        _ = ShowWindow(childHandle, SwShow);

        if (!MoveWindow(childHandle, 0, 0, bounds.Width, bounds.Height, true))
        {
            ThrowWin32Exception("MoveWindow");
        }

        if (!SetWindowPos(
                childHandle,
                IntPtr.Zero,
                0,
                0,
                bounds.Width,
                bounds.Height,
                SwpFrameChanged | SwpNoActivate | SwpNoOwnerZOrder | SwpNoZOrder | SwpShowWindow))
        {
            ThrowWin32Exception("SetWindowPos");
        }
    }

    private static void ApplyHostedWindowStyles(
        IntPtr childHandle,
        IntPtr originalStyle,
        IntPtr originalExStyle)
    {
        var hostedStyle = (originalStyle.ToInt64() | WsChild) & ~WsPopup & ~WsCaption & ~WsThickFrame;
        var hostedExStyle = (originalExStyle.ToInt64() & ~WsExAppWindow) & ~WsExToolWindow;
        SetWindowLongPtrOrThrow(childHandle, GwlStyle, new IntPtr(hostedStyle));
        SetWindowLongPtrOrThrow(childHandle, GwlExStyle, new IntPtr(hostedExStyle));
    }

    private static void RestoreWindowStyles(IntPtr childHandle, IntPtr originalStyle, IntPtr originalExStyle)
    {
        SetWindowLongPtrOrThrow(childHandle, GwlStyle, originalStyle);
        SetWindowLongPtrOrThrow(childHandle, GwlExStyle, originalExStyle);
        _ = SetWindowPos(
            childHandle,
            IntPtr.Zero,
            0,
            0,
            0,
            0,
            SwpFrameChanged | SwpNoActivate | SwpNoOwnerZOrder | SwpNoZOrder);
    }

    private static IntPtr ResolveRestoreParent(IntPtr originalParentHandle)
    {
        return originalParentHandle != IntPtr.Zero && IsWindow(originalParentHandle)
            ? originalParentHandle
            : IntPtr.Zero;
    }

    private static void SetParentOrThrow(IntPtr childHandle, IntPtr hostHandle)
    {
        SetLastError(0);
        _ = SetParent(childHandle, hostHandle);
        var setParentErrorCode = Marshal.GetLastWin32Error();
        var actualParent = GetParent(childHandle);

        if (actualParent != hostHandle)
        {
            ThrowWin32Exception("SetParent", setParentErrorCode);
        }
    }

    private static void ValidateWindowHandle(IntPtr handle, string parameterName)
    {
        if (handle == IntPtr.Zero)
        {
            throw new ArgumentException("A valid window handle is required.", parameterName);
        }

        if (!IsWindow(handle))
        {
            throw new ArgumentException("The supplied handle does not reference a live window.", parameterName);
        }
    }

    private static void ThrowWin32Exception(string operation)
    {
        ThrowWin32Exception(operation, Marshal.GetLastWin32Error());
    }

    private static void ThrowWin32Exception(string operation, int errorCode)
    {
        throw new Win32Exception(errorCode, operation + " failed. Win32Error=" + errorCode + ".");
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool IsWindow(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool MoveWindow(
        IntPtr hWnd,
        int x,
        int y,
        int nWidth,
        int nHeight,
        bool bRepaint);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetWindowPos(
        IntPtr hWnd,
        IntPtr hWndInsertAfter,
        int x,
        int y,
        int cx,
        int cy,
        uint uFlags);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr GetParent(IntPtr hWnd);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtr", SetLastError = true)]
    private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "GetWindowLong", SetLastError = true)]
    private static extern int GetWindowLong32(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtr", SetLastError = true)]
    private static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

    [DllImport("user32.dll", EntryPoint = "SetWindowLong", SetLastError = true)]
    private static extern int SetWindowLong32(IntPtr hWnd, int nIndex, int dwNewLong);

    private static IntPtr GetWindowLongPtr(IntPtr hWnd, int nIndex)
    {
        return IntPtr.Size == 8
            ? GetWindowLongPtr64(hWnd, nIndex)
            : new IntPtr(GetWindowLong32(hWnd, nIndex));
    }

    private static void SetWindowLongPtrOrThrow(IntPtr hWnd, int nIndex, IntPtr newValue)
    {
        SetLastError(0);
        var previous = IntPtr.Size == 8
            ? SetWindowLongPtr64(hWnd, nIndex, newValue)
            : new IntPtr(SetWindowLong32(hWnd, nIndex, newValue.ToInt32()));

        if (previous == IntPtr.Zero && Marshal.GetLastWin32Error() != 0)
        {
            ThrowWin32Exception("SetWindowLongPtr");
        }
    }

    [DllImport("kernel32.dll")]
    private static extern void SetLastError(uint dwErrCode);

    [DllImport("user32.dll")]
    private static extern int SetThreadDpiHostingBehavior(int value);

    private sealed class DpiHostingScope : IDisposable
    {
        private readonly int _previousBehavior;

        private DpiHostingScope(int previousBehavior)
        {
            _previousBehavior = previousBehavior;
        }

        public static DpiHostingScope EnableMixedHosting()
        {
            if (!OperatingSystem.IsWindowsVersionAtLeast(10, 0, 16299))
            {
                return new DpiHostingScope(DpiHostingBehaviorInvalid);
            }

            return new DpiHostingScope(SetThreadDpiHostingBehavior(DpiHostingBehaviorMixed));
        }

        public void Dispose()
        {
            if (_previousBehavior != DpiHostingBehaviorInvalid)
            {
                _ = SetThreadDpiHostingBehavior(_previousBehavior);
            }
        }
    }

}
