using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;

namespace DingTalkWindowsHost.Automation.WindowHost;

public sealed record WindowCandidate(
    IntPtr Handle,
    string Title,
    string ClassName,
    bool IsVisible,
    bool IsEnabled,
    bool IsTopLevel,
    bool IsToolWindow,
    int Width,
    int Height,
    int ZOrder,
    string ProcessName = "")
{
    public int Area => Width * Height;
}

public sealed class DingTalkWindowLocator
{
    private const int ExStyleToolWindow = 0x00000080;
    private const uint GaRoot = 2;
    private const uint GwOwner = 4;
    private static readonly string[] ChatChildClassNames =
    {
        "DingChatWnd",
    };
    private static readonly string[] ChatBrowserClassNames =
    {
        "CefBrowserWindow",
        "Chrome_WidgetWin_1",
    };
    private const string DingTalkStandardFrameClassName = "StandardFrame_DingTalk";

    private readonly Func<IReadOnlyList<WindowCandidate>> _candidateSource;

    public DingTalkWindowLocator()
        : this(EnumerateDesktopWindows)
    {
    }

    public DingTalkWindowLocator(Func<IReadOnlyList<WindowCandidate>> candidateSource)
    {
        ArgumentNullException.ThrowIfNull(candidateSource);
        _candidateSource = candidateSource;
    }

    public IReadOnlyList<WindowCandidate> GetWindowCandidates()
    {
        return _candidateSource()
            .Where(IsLikelyDingTalkWindow)
            .ToArray();
    }

    public IReadOnlyList<WindowCandidate> GetDescendantWindowCandidates(IntPtr rootHandle)
    {
        if (rootHandle == IntPtr.Zero)
        {
            return Array.Empty<WindowCandidate>();
        }

        var candidates = EnumerateDescendantWindows(rootHandle);
        var rootCandidate = candidates.FirstOrDefault(candidate => candidate.Handle == rootHandle);
        var rootProcessName = rootCandidate?.ProcessName ?? string.Empty;
        return candidates
            .Where(candidate => candidate.Handle != rootHandle)
            .Where(candidate =>
                IsLikelyDingTalkWindow(candidate)
                || (!string.IsNullOrWhiteSpace(rootProcessName)
                    && string.Equals(candidate.ProcessName, rootProcessName, StringComparison.OrdinalIgnoreCase)))
            .ToArray();
    }

    public WindowCandidate? ChooseMainWindow(IEnumerable<WindowCandidate> candidates)
    {
        ArgumentNullException.ThrowIfNull(candidates);

        return candidates
            .Where(IsEligibleMainWindow)
            .OrderByDescending(GetCandidatePriority)
            .ThenByDescending(candidate => candidate.Area)
            .ThenByDescending(candidate => candidate.Width)
            .ThenByDescending(candidate => candidate.Height)
            .ThenBy(candidate => candidate.ZOrder)
            .FirstOrDefault();
    }

    public static bool IsLikelyDingTalkWindow(WindowCandidate candidate)
    {
        if (ContainsHostShellSignal(candidate.ProcessName) || ContainsHostShellSignal(candidate.ClassName))
        {
            return false;
        }

        return string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
            || candidate.Title.Contains("\u9489\u9489", StringComparison.OrdinalIgnoreCase);
    }

    internal static bool IsEligibleMainWindow(WindowCandidate candidate)
    {
        if (DingTalkTransientOverlayClassifier.IsTransientOverlay(candidate))
        {
            return false;
        }

        if (IsDingTalkStandardFrame(candidate))
        {
            return candidate.Handle != IntPtr.Zero
                && candidate.IsEnabled
                && candidate.IsTopLevel
                && !candidate.IsToolWindow;
        }

        return candidate.Handle != IntPtr.Zero
            && candidate.IsEnabled
            && (!candidate.IsToolWindow || IsRecoverableHiddenWorkspace(candidate))
            && (IsLikelyDingTalkContentWindow(candidate)
                || IsRecoverableHiddenWorkspace(candidate))
            && (HasAttachableSize(candidate)
                || IsVisibleDingTalkMainQtFrame(candidate)
                || IsTopLevelDingTalkChatWindow(candidate));
    }

    private static bool IsLikelyDingTalkContentWindow(WindowCandidate candidate)
    {
        if (string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
            && (string.Equals(candidate.ClassName, "Chrome_WidgetWin_0", StringComparison.OrdinalIgnoreCase)
                || IsDingTalkStandardFrame(candidate)
                || IsDingTalkChatWindow(candidate)
                || IsVisibleDingTalkMainQtFrame(candidate)
                || IsChatChildWindow(candidate)
                || IsChatBrowserContainer(candidate)))
        {
            return true;
        }

        if (candidate.IsVisible
            && !string.IsNullOrWhiteSpace(candidate.Title)
            && !IsGenericQtWorkspace(candidate))
        {
            return candidate.IsTopLevel;
        }

        return false;
    }

    private static bool IsChatChildWindow(WindowCandidate candidate)
    {
        return string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
            && !candidate.IsTopLevel
            && candidate.IsVisible
            && (IsDingTalkChatModule(candidate)
                || IsDingTalkChatWindow(candidate));
    }

    private static int GetCandidatePriority(WindowCandidate candidate)
    {
        if (IsDingTalkChatModule(candidate))
        {
            return 25;
        }

        if (IsTopLevelDingTalkChatWindow(candidate))
        {
            return 24;
        }

        if (IsChatChildWindow(candidate))
        {
            return 21;
        }

        if (IsVisibleDingTalkMainQtFrame(candidate))
        {
            return 22;
        }

        if (IsDingTalkStandardFrame(candidate))
        {
            return 20;
        }

        if (candidate.IsTopLevel
            && string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
            && string.Equals(candidate.ClassName, "Chrome_WidgetWin_0", StringComparison.OrdinalIgnoreCase))
        {
            return 7;
        }

        if (IsChatBrowserContainer(candidate))
        {
            return 14;
        }

        if (candidate.IsTopLevel && candidate.IsVisible && !string.IsNullOrWhiteSpace(candidate.Title))
        {
            return 20;
        }

        if (IsRecoverableHiddenWorkspace(candidate))
        {
            return 5;
        }

        return 0;
    }

    private static bool IsDingTalkChatModule(WindowCandidate candidate)
    {
        return string.Equals(candidate.Title, "DTIMChatModule", StringComparison.OrdinalIgnoreCase)
            && string.Equals(candidate.ClassName, "Qt51511QWindowIcon", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsDingTalkChatWindow(WindowCandidate candidate)
    {
        return string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
            && candidate.IsVisible
            && candidate.IsEnabled
            && ChatChildClassNames.Any(className =>
                string.Equals(candidate.ClassName, className, StringComparison.OrdinalIgnoreCase));
    }

    private static bool IsTopLevelDingTalkChatWindow(WindowCandidate candidate)
    {
        return IsDingTalkChatWindow(candidate)
            && candidate.IsTopLevel
            && !candidate.IsToolWindow;
    }

    private static bool IsChatBrowserContainer(WindowCandidate candidate)
    {
        return string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
            && candidate.IsVisible
            && candidate.IsEnabled
            && ChatBrowserClassNames.Any(className =>
                string.Equals(candidate.ClassName, className, StringComparison.OrdinalIgnoreCase));
    }

    private static bool IsGenericQtWorkspace(WindowCandidate candidate)
    {
        return string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
            && string.Equals(candidate.ClassName, "Qt51511QWindowIcon", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsVisibleDingTalkMainQtFrame(WindowCandidate candidate)
    {
        return IsGenericQtWorkspace(candidate)
            && candidate.IsVisible
            && candidate.IsEnabled
            && candidate.IsTopLevel
            && !candidate.IsToolWindow
            && HasUsableVisibleMainQtFrameSize(candidate)
            && (string.Equals(candidate.Title, "\u9489\u9489", StringComparison.OrdinalIgnoreCase)
                || string.Equals(candidate.Title, "DingTalk", StringComparison.OrdinalIgnoreCase));
    }

    private static bool HasUsableVisibleMainQtFrameSize(WindowCandidate candidate)
    {
        return HasAttachableSize(candidate)
            || (candidate.Width == 0
                && candidate.Height == 0
                && string.Equals(candidate.Title, "\u9489\u9489", StringComparison.OrdinalIgnoreCase));
    }

    private static bool IsDingTalkStandardFrame(WindowCandidate candidate)
    {
        return string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
            && string.Equals(candidate.ClassName, DingTalkStandardFrameClassName, StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsRecoverableHiddenWorkspace(WindowCandidate candidate)
    {
        return string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
            && candidate.IsTopLevel
            && !candidate.IsVisible
            && candidate.IsEnabled
            && string.Equals(candidate.ClassName, "Qt51511QWindowIcon", StringComparison.OrdinalIgnoreCase)
            && candidate.Width >= 320
            && candidate.Height >= 240
            && (string.Equals(candidate.Title, "DingTalk", StringComparison.OrdinalIgnoreCase)
                || string.Equals(candidate.Title, "\u9489\u9489", StringComparison.OrdinalIgnoreCase));
    }

    private static bool HasAttachableSize(WindowCandidate candidate)
    {
        return candidate.Width >= 320 && candidate.Height >= 240;
    }

    private static IReadOnlyList<WindowCandidate> EnumerateDesktopWindows()
    {
        var candidates = new List<WindowCandidate>();
        var zOrder = 0;

        _ = EnumWindows((handle, lParam) =>
        {
            var candidate = CreateWindowCandidate(handle, zOrder++);
            candidates.Add(candidate);

            if (IsLikelyDingTalkWindow(candidate))
            {
                _ = EnumChildWindows(handle, (childHandle, childLParam) =>
                {
                    candidates.Add(CreateWindowCandidate(childHandle, zOrder++));
                    return true;
                }, IntPtr.Zero);
            }

            return true;
        }, IntPtr.Zero);

        return candidates;
    }

    private static IReadOnlyList<WindowCandidate> EnumerateDescendantWindows(IntPtr rootHandle)
    {
        var candidates = new List<WindowCandidate>();
        var zOrder = 0;

        candidates.Add(CreateWindowCandidate(rootHandle, zOrder++));
        _ = EnumChildWindows(rootHandle, (childHandle, childLParam) =>
        {
            candidates.Add(CreateWindowCandidate(childHandle, zOrder++));
            return true;
        }, IntPtr.Zero);
        return candidates;
    }

    private static WindowCandidate CreateWindowCandidate(IntPtr handle, int zOrder)
    {
        var bounds = GetBounds(handle);
        return new WindowCandidate(
            Handle: handle,
            Title: GetWindowTitle(handle),
            ClassName: GetWindowClassName(handle),
            IsVisible: IsWindowVisible(handle),
            IsEnabled: IsWindowEnabled(handle),
            IsTopLevel: IsTopLevelWindow(handle),
            IsToolWindow: IsToolWindow(handle),
            Width: bounds.Width,
            Height: bounds.Height,
            ZOrder: zOrder,
            ProcessName: GetProcessName(handle));
    }

    private static bool ContainsHostShellSignal(string value)
    {
        return !string.IsNullOrWhiteSpace(value)
            && value.Contains("DingTalkWindowsHost", StringComparison.OrdinalIgnoreCase);
    }

    private static HostSurfaceBounds GetBounds(IntPtr handle)
    {
        return GetWindowRect(handle, out var rect)
            ? new HostSurfaceBounds(rect.Right - rect.Left, rect.Bottom - rect.Top)
            : new HostSurfaceBounds(0, 0);
    }

    private static string GetWindowTitle(IntPtr handle)
    {
        var length = GetWindowTextLength(handle);
        if (length <= 0)
        {
            return string.Empty;
        }

        var buffer = new StringBuilder(length + 1);
        _ = GetWindowText(handle, buffer, buffer.Capacity);
        return buffer.ToString();
    }

    private static string GetWindowClassName(IntPtr handle)
    {
        var buffer = new StringBuilder(256);
        _ = GetClassName(handle, buffer, buffer.Capacity);
        return buffer.ToString();
    }

    private static string GetProcessName(IntPtr handle)
    {
        _ = GetWindowThreadProcessId(handle, out var processId);
        if (processId == 0)
        {
            return string.Empty;
        }

        try
        {
            using var process = Process.GetProcessById((int)processId);
            return process.ProcessName;
        }
        catch (ArgumentException)
        {
            return string.Empty;
        }
        catch (InvalidOperationException)
        {
            return string.Empty;
        }
        catch (Win32Exception)
        {
            return string.Empty;
        }
    }

    private static bool IsTopLevelWindow(IntPtr handle)
    {
        return GetAncestor(handle, GaRoot) == handle
            && GetWindow(handle, GwOwner) == IntPtr.Zero;
    }

    private static bool IsToolWindow(IntPtr handle)
    {
        return (GetWindowLongPtr(handle, NativeWindowIndex.GwlExStyle).ToInt64() & ExStyleToolWindow) != 0;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool EnumChildWindows(IntPtr hWndParent, EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool IsWindowEnabled(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool GetWindowRect(IntPtr hWnd, out WindowRect lpRect);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr GetWindow(IntPtr hWnd, uint uCmd);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr GetAncestor(IntPtr hWnd, uint gaFlags);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtr", SetLastError = true)]
    private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "GetWindowLong", SetLastError = true)]
    private static extern int GetWindowLong32(IntPtr hWnd, int nIndex);

    private static IntPtr GetWindowLongPtr(IntPtr hWnd, int nIndex)
    {
        return IntPtr.Size == 8
            ? GetWindowLongPtr64(hWnd, nIndex)
            : new IntPtr(GetWindowLong32(hWnd, nIndex));
    }

    private static class NativeWindowIndex
    {
        public const int GwlExStyle = -20;
    }

    [StructLayout(LayoutKind.Sequential)]
    private readonly struct WindowRect
    {
        public readonly int Left;
        public readonly int Top;
        public readonly int Right;
        public readonly int Bottom;
    }
}
