using DingTalkWindowsHost.Automation.WindowHost;

namespace DingTalkWindowsHost.Automation.Capture;

public sealed class UiaMessageProbeCoordinator
{
    private const int MaxProbeTargets = 8;

    private readonly Func<IntPtr, IReadOnlyList<WindowCandidate>> _descendantCandidateProvider;
    private readonly Func<IntPtr> _hostedWindowHandle;
    private readonly DingTalkWindowLocator _windowLocator;
    private readonly Func<IntPtr, ExtractedMessage?> _clipboardProbe;
    private readonly Func<IntPtr, ExtractedMessage?> _windowProbe;

    public UiaMessageProbeCoordinator(
        DingTalkWindowLocator windowLocator,
        UiaChatSurfaceProbe chatSurfaceProbe,
        Func<IntPtr> hostedWindowHandle)
        : this(
            windowLocator,
            hostedWindowHandle,
            chatSurfaceProbe.ProbeLatest,
            windowLocator.GetDescendantWindowCandidates,
            _ => null)
    {
    }

    public UiaMessageProbeCoordinator(
        DingTalkWindowLocator windowLocator,
        UiaChatSurfaceProbe chatSurfaceProbe,
        Func<IntPtr> hostedWindowHandle,
        Func<IntPtr, ExtractedMessage?> clipboardProbe)
        : this(
            windowLocator,
            hostedWindowHandle,
            chatSurfaceProbe.ProbeLatest,
            windowLocator.GetDescendantWindowCandidates,
            clipboardProbe)
    {
    }

    public UiaMessageProbeCoordinator(
        DingTalkWindowLocator windowLocator,
        Func<IntPtr> hostedWindowHandle,
        Func<IntPtr, ExtractedMessage?> windowProbe,
        Func<IntPtr, IReadOnlyList<WindowCandidate>> descendantCandidateProvider)
        : this(
            windowLocator,
            hostedWindowHandle,
            windowProbe,
            descendantCandidateProvider,
            _ => null)
    {
    }

    public UiaMessageProbeCoordinator(
        DingTalkWindowLocator windowLocator,
        Func<IntPtr> hostedWindowHandle,
        Func<IntPtr, ExtractedMessage?> windowProbe,
        Func<IntPtr, IReadOnlyList<WindowCandidate>> descendantCandidateProvider,
        Func<IntPtr, ExtractedMessage?> clipboardProbe)
    {
        ArgumentNullException.ThrowIfNull(windowLocator);
        ArgumentNullException.ThrowIfNull(hostedWindowHandle);
        ArgumentNullException.ThrowIfNull(windowProbe);
        ArgumentNullException.ThrowIfNull(descendantCandidateProvider);
        ArgumentNullException.ThrowIfNull(clipboardProbe);

        _windowLocator = windowLocator;
        _hostedWindowHandle = hostedWindowHandle;
        _windowProbe = windowProbe;
        _descendantCandidateProvider = descendantCandidateProvider;
        _clipboardProbe = clipboardProbe;
    }

    public ExtractedMessage? ProbeLatest()
    {
        var handles = BuildProbeHandles();
        foreach (var handle in handles)
        {
            var extracted = _windowProbe(handle);
            if (extracted is not null)
            {
                return extracted;
            }
        }

        var clipboardTarget = handles.FirstOrDefault();
        return clipboardTarget == IntPtr.Zero
            ? null
            : _clipboardProbe(clipboardTarget);
    }

    internal IReadOnlyList<IntPtr> BuildProbeHandles()
    {
        var hostedHandle = _hostedWindowHandle();
        var candidates = _windowLocator.GetWindowCandidates();
        var selected = _windowLocator.ChooseMainWindow(candidates);
        var emitted = new HashSet<IntPtr>();
        var handles = new List<IntPtr>();

        AddHandle(hostedHandle);
        AddHandle(selected?.Handle ?? IntPtr.Zero);

        foreach (var candidate in candidates
                     .Where(IsMainWorkspaceCandidate)
                     .OrderByDescending(static candidate => candidate.Area)
                     .ThenBy(static candidate => candidate.ZOrder))
        {
            AddHandle(candidate.Handle);
        }

        if (hostedHandle != IntPtr.Zero)
        {
            foreach (var candidate in _descendantCandidateProvider(hostedHandle)
                         .Where(IsMessageContentCandidate)
                         .OrderBy(GetProbeRank)
                         .ThenByDescending(static candidate => candidate.Area)
                         .ThenBy(static candidate => candidate.ZOrder))
            {
                AddHandle(candidate.Handle);
            }
        }

        foreach (var candidate in candidates
                     .Where(IsMessageContentCandidate)
                     .OrderBy(GetProbeRank)
                     .ThenByDescending(static candidate => candidate.Area)
                     .ThenBy(static candidate => candidate.ZOrder))
        {
            AddHandle(candidate.Handle);
        }

        return handles;

        void AddHandle(IntPtr handle)
        {
            if (handle == IntPtr.Zero || handles.Count >= MaxProbeTargets || !emitted.Add(handle))
            {
                return;
            }

            handles.Add(handle);
        }
    }

    private static bool IsMessageContentCandidate(WindowCandidate candidate)
    {
        if (candidate.Handle == IntPtr.Zero
            || !candidate.IsEnabled
            || candidate.IsToolWindow
            || !string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        return IsKnownMessageContentClass(candidate)
            || IsKnownMessageContentTitle(candidate);
    }

    private static bool IsMainWorkspaceCandidate(WindowCandidate candidate)
    {
        if (candidate.Handle == IntPtr.Zero
            || !candidate.IsEnabled
            || !candidate.IsVisible
            || !candidate.IsTopLevel
            || candidate.IsToolWindow
            || !string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        return string.Equals(candidate.ClassName, "Qt51511QWindowIcon", StringComparison.OrdinalIgnoreCase)
            && (string.Equals(candidate.Title, "\u9489\u9489", StringComparison.OrdinalIgnoreCase)
                || string.Equals(candidate.Title, "DingTalk", StringComparison.OrdinalIgnoreCase));
    }

    private static bool IsKnownMessageContentClass(WindowCandidate candidate)
    {
        return string.Equals(candidate.ClassName, "Qt51511QWindowIcon", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "QWindowContainer", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "Chrome_RenderWidgetHostHWND", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "Chrome_WidgetWin_1", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "CefBrowserWindow", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsKnownMessageContentTitle(WindowCandidate candidate)
    {
        return string.Equals(candidate.Title, "DTIMChatModule", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.Title, "DTIMContentModule", StringComparison.OrdinalIgnoreCase);
    }

    private static int GetProbeRank(WindowCandidate candidate)
    {
        if (string.Equals(candidate.Title, "DTIMContentModule", StringComparison.OrdinalIgnoreCase))
        {
            return 0;
        }

        if (string.Equals(candidate.Title, "DTIMChatModule", StringComparison.OrdinalIgnoreCase))
        {
            return 1;
        }

        if (string.Equals(candidate.ClassName, "Chrome_RenderWidgetHostHWND", StringComparison.OrdinalIgnoreCase))
        {
            return 2;
        }

        if (string.Equals(candidate.ClassName, "QWindowContainer", StringComparison.OrdinalIgnoreCase))
        {
            return 3;
        }

        if (string.Equals(candidate.ClassName, "Chrome_WidgetWin_1", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "CefBrowserWindow", StringComparison.OrdinalIgnoreCase))
        {
            return 4;
        }

        return 5;
    }
}
