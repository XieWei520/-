using DingTalkWindowsHost.Automation.WindowHost;
using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Contracts.Services;

namespace DingTalkWindowsHost.Automation.Capture;

public sealed class UiaCandidateDiagnosticsProvider : IUiaCandidateDiagnosticsProvider
{
    private static readonly string[] ContentClassNames =
    {
        "StandardFrame_DingTalk",
        "DingChatWnd",
        "CefBrowserWindow",
        "Chrome_WidgetWin_1",
        "Chrome_RenderWidgetHostHWND",
    };

    private readonly DingTalkWindowLocator _windowLocator;
    private readonly Func<IntPtr> _hostedWindowHandle;
    private readonly Func<IntPtr, int, IReadOnlyList<string>> _nodeSummaryProvider;
    private readonly Func<IntPtr, int, UiaConversationDiagnosticsResult> _conversationDiagnosticsProvider;
    private readonly Func<IntPtr, IReadOnlyList<WindowCandidate>> _descendantCandidateProvider;

    public UiaCandidateDiagnosticsProvider(
        DingTalkWindowLocator windowLocator,
        UiaChatSurfaceProbe chatSurfaceProbe,
        Func<IntPtr> hostedWindowHandle)
        : this(
            windowLocator,
            hostedWindowHandle,
            chatSurfaceProbe.ProbeNodeSummary,
            chatSurfaceProbe.ProbeConversationDiagnostics,
            windowLocator.GetDescendantWindowCandidates)
    {
    }

    public UiaCandidateDiagnosticsProvider(
        DingTalkWindowLocator windowLocator,
        Func<IntPtr> hostedWindowHandle,
        Func<IntPtr, int, IReadOnlyList<string>> nodeSummaryProvider,
        Func<IntPtr, int, UiaConversationDiagnosticsResult> conversationDiagnosticsProvider)
        : this(
            windowLocator,
            hostedWindowHandle,
            nodeSummaryProvider,
            conversationDiagnosticsProvider,
            windowLocator.GetDescendantWindowCandidates)
    {
    }

    public UiaCandidateDiagnosticsProvider(
        DingTalkWindowLocator windowLocator,
        Func<IntPtr> hostedWindowHandle,
        Func<IntPtr, int, IReadOnlyList<string>> nodeSummaryProvider,
        Func<IntPtr, int, UiaConversationDiagnosticsResult> conversationDiagnosticsProvider,
        Func<IntPtr, IReadOnlyList<WindowCandidate>> descendantCandidateProvider)
    {
        ArgumentNullException.ThrowIfNull(windowLocator);
        ArgumentNullException.ThrowIfNull(hostedWindowHandle);
        ArgumentNullException.ThrowIfNull(nodeSummaryProvider);
        ArgumentNullException.ThrowIfNull(conversationDiagnosticsProvider);
        ArgumentNullException.ThrowIfNull(descendantCandidateProvider);

        _windowLocator = windowLocator;
        _hostedWindowHandle = hostedWindowHandle;
        _nodeSummaryProvider = nodeSummaryProvider;
        _conversationDiagnosticsProvider = conversationDiagnosticsProvider;
        _descendantCandidateProvider = descendantCandidateProvider;
    }

    public UiaCandidateDiagnosticsResult ProbeCandidates(
        int candidateLimit,
        int snapshotLimit,
        int conversationLimit)
    {
        var normalizedCandidateLimit = Math.Max(0, candidateLimit);
        var normalizedSnapshotLimit = Math.Max(0, snapshotLimit);
        var normalizedConversationLimit = Math.Max(0, conversationLimit);
        var candidates = _windowLocator.GetWindowCandidates();
        var selected = _windowLocator.ChooseMainWindow(candidates);
        var hostedHandle = _hostedWindowHandle();
        var descendantCandidates = hostedHandle == IntPtr.Zero
            ? Array.Empty<WindowCandidate>()
            : _descendantCandidateProvider(hostedHandle);
        var probes = BuildProbeTargets(candidates, descendantCandidates, selected, hostedHandle)
            .Take(normalizedCandidateLimit)
            .Select(candidate => ProbeCandidate(
                candidate,
                selected,
                hostedHandle,
                normalizedSnapshotLimit,
                normalizedConversationLimit))
            .ToArray();

        return new UiaCandidateDiagnosticsResult(
            ObservedAt: DateTimeOffset.UtcNow,
            Recommendation: BuildRecommendation(probes),
            HostedHwnd: FormatHandleOrEmpty(hostedHandle),
            SelectedWindowCandidateHwnd: FormatHandleOrEmpty(selected?.Handle ?? IntPtr.Zero),
            TotalCandidates: candidates.Count,
            Probes: probes);
    }

    private static IEnumerable<WindowCandidate> BuildProbeTargets(
        IReadOnlyList<WindowCandidate> candidates,
        IReadOnlyList<WindowCandidate> descendantCandidates,
        WindowCandidate? selected,
        IntPtr hostedHandle)
    {
        var byHandle = candidates.ToDictionary(static candidate => candidate.Handle);
        var emitted = new HashSet<IntPtr>();

        if (hostedHandle != IntPtr.Zero)
        {
            yield return byHandle.TryGetValue(hostedHandle, out var hostedCandidate)
                ? hostedCandidate
                : CreateHostedCandidate(hostedHandle);
            emitted.Add(hostedHandle);
        }

        if (selected is not null && emitted.Add(selected.Handle))
        {
            yield return selected;
        }

        foreach (var candidate in descendantCandidates
                     .Where(IsWorthProbing)
                     .OrderBy(GetProbeRank)
                     .ThenByDescending(static candidate => candidate.Area)
                     .ThenBy(static candidate => candidate.ZOrder))
        {
            if (emitted.Add(candidate.Handle))
            {
                yield return candidate;
            }
        }

        foreach (var candidate in candidates
                     .Where(IsWorthProbing)
                     .OrderBy(GetProbeRank)
                     .ThenByDescending(static candidate => candidate.Area)
                     .ThenBy(static candidate => candidate.ZOrder))
        {
            if (emitted.Add(candidate.Handle))
            {
                yield return candidate;
            }
        }
    }

    private UiaCandidateProbe ProbeCandidate(
        WindowCandidate candidate,
        WindowCandidate? selected,
        IntPtr hostedHandle,
        int snapshotLimit,
        int conversationLimit)
    {
        try
        {
            var diagnostics = _conversationDiagnosticsProvider(candidate.Handle, conversationLimit);
            var summary = _nodeSummaryProvider(candidate.Handle, snapshotLimit);
            return new UiaCandidateProbe(
                Hwnd: FormatHandle(candidate.Handle),
                Title: candidate.Title,
                ClassName: candidate.ClassName,
                ProcessName: candidate.ProcessName,
                IsHosted: candidate.Handle == hostedHandle,
                IsSelectedWindowCandidate: selected?.Handle == candidate.Handle,
                IsVisible: candidate.IsVisible,
                IsTopLevel: candidate.IsTopLevel,
                Width: candidate.Width,
                Height: candidate.Height,
                Readiness: ConversationReadinessEvaluator.Evaluate(diagnostics),
                ConversationCount: diagnostics.Conversations.Count,
                BlockingDialogCount: diagnostics.BlockingDialogs.Count,
                Recommendation: diagnostics.Recommendation,
                NodeSummary: summary,
                Error: string.Empty);
        }
        catch (Exception ex)
        {
            return BuildFailedProbe(candidate, selected, hostedHandle, ex);
        }
    }

    private static UiaCandidateProbe BuildFailedProbe(
        WindowCandidate candidate,
        WindowCandidate? selected,
        IntPtr hostedHandle,
        Exception exception)
    {
        return new UiaCandidateProbe(
            Hwnd: FormatHandle(candidate.Handle),
            Title: candidate.Title,
            ClassName: candidate.ClassName,
            ProcessName: candidate.ProcessName,
            IsHosted: candidate.Handle == hostedHandle,
            IsSelectedWindowCandidate: selected?.Handle == candidate.Handle,
            IsVisible: candidate.IsVisible,
            IsTopLevel: candidate.IsTopLevel,
            Width: candidate.Width,
            Height: candidate.Height,
            Readiness: ConversationReadiness.DiagnosticsError,
            ConversationCount: 0,
            BlockingDialogCount: 0,
            Recommendation: "uia-candidate-probe-error type='"
                + exception.GetType().Name
                + "' message='"
                + exception.Message
                + "'",
            NodeSummary: Array.Empty<string>(),
            Error: exception.GetType().Name + ": " + exception.Message);
    }

    private static bool IsWorthProbing(WindowCandidate candidate)
    {
        if (candidate.Handle == IntPtr.Zero
            || !candidate.IsEnabled
            || candidate.IsToolWindow
            || ((candidate.Width < 320 || candidate.Height < 240)
                && !IsVisibleDingTalkMainQtFrame(candidate)
                && !IsKnownHostedContentContainer(candidate)))
        {
            return false;
        }

        return string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
            && (candidate.IsVisible
                || IsDingTalkChatModule(candidate)
                || IsKnownHostedContentContainer(candidate)
                || IsKnownContentClass(candidate));
    }

    private static int GetProbeRank(WindowCandidate candidate)
    {
        if (IsKnownContentClass(candidate)
            && !string.Equals(candidate.ClassName, "StandardFrame_DingTalk", StringComparison.OrdinalIgnoreCase))
        {
            return 0;
        }

        if (IsDingTalkChatModule(candidate))
        {
            return 1;
        }

        if (string.Equals(candidate.ClassName, "StandardFrame_DingTalk", StringComparison.OrdinalIgnoreCase))
        {
            return 2;
        }

        if (IsKnownHostedContentContainer(candidate))
        {
            return 3;
        }

        return candidate.IsVisible ? 4 : 5;
    }

    private static bool IsKnownContentClass(WindowCandidate candidate)
    {
        return ContentClassNames.Any(className =>
            string.Equals(candidate.ClassName, className, StringComparison.OrdinalIgnoreCase));
    }

    private static bool IsKnownHostedContentContainer(WindowCandidate candidate)
    {
        return string.Equals(candidate.Title, "DTIMContentModule", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "QWindowContainer", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "Chrome_WidgetWin_0", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsDingTalkChatModule(WindowCandidate candidate)
    {
        return string.Equals(candidate.Title, "DTIMChatModule", StringComparison.OrdinalIgnoreCase)
            && string.Equals(candidate.ClassName, "Qt51511QWindowIcon", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsVisibleDingTalkMainQtFrame(WindowCandidate candidate)
    {
        return string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
            && string.Equals(candidate.ClassName, "Qt51511QWindowIcon", StringComparison.OrdinalIgnoreCase)
            && candidate.IsVisible
            && candidate.IsEnabled
            && candidate.IsTopLevel
            && !candidate.IsToolWindow
            && string.Equals(candidate.Title, "\u9489\u9489", StringComparison.OrdinalIgnoreCase);
    }

    private static string BuildRecommendation(IReadOnlyList<UiaCandidateProbe> probes)
    {
        var readyProbe = probes.FirstOrDefault(static probe =>
            probe.Readiness is ConversationReadiness.Ready or ConversationReadiness.ConversationListVisible);
        if (readyProbe is not null)
        {
            return "UIA conversation list is available on candidate " + readyProbe.Hwnd + ".";
        }

        if (probes.Count == 0)
        {
            return "No DingTalk HWND candidate was available for UIA probing.";
        }

        if (probes.Any(static probe => probe.Readiness == ConversationReadiness.LoginRequired))
        {
            return "DingTalk login UI is visible on at least one candidate; sign in before capture.";
        }

        if (probes.Any(static probe => probe.Readiness == ConversationReadiness.BlockedByDialog))
        {
            return "A blocking DingTalk dialog is visible on at least one candidate.";
        }

        return "No probed HWND exposed the conversation list through UIA; inspect candidate node summaries.";
    }

    private static WindowCandidate CreateHostedCandidate(IntPtr hostedHandle)
    {
        return new WindowCandidate(
            Handle: hostedHandle,
            Title: string.Empty,
            ClassName: string.Empty,
            IsVisible: true,
            IsEnabled: true,
            IsTopLevel: false,
            IsToolWindow: false,
            Width: 0,
            Height: 0,
            ZOrder: 0,
            ProcessName: "DingTalk");
    }

    private static string FormatHandleOrEmpty(IntPtr handle)
    {
        return handle == IntPtr.Zero ? string.Empty : FormatHandle(handle);
    }

    private static string FormatHandle(IntPtr handle)
    {
        return "0x" + handle.ToInt64().ToString("X");
    }
}
