using System.Security.Cryptography;
using System.Text;
using DingTalkWindowsHost.Automation.WindowHost;
using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Contracts.Services;

namespace DingTalkWindowsHost.Automation.Capture;

public sealed class UiaTextCandidateDiagnosticsProvider : IUiaTextCandidateDiagnosticsProvider
{
    private const int MaxCandidateLimit = 20;
    private const int MaxSnapshotLimit = 1000;
    private const int MaxTextCandidatesPerWindow = 80;

    private static readonly string[] ContentClassNames =
    {
        "StandardFrame_DingTalk",
        "DingChatWnd",
        "CefBrowserWindow",
        "Chrome_WidgetWin_0",
        "Chrome_WidgetWin_1",
        "Chrome_RenderWidgetHostHWND",
        "QWindowContainer",
        "Qt51511QWindowIcon",
    };

    private readonly Func<IReadOnlyList<WindowCandidate>> _candidateProvider;
    private readonly Func<IntPtr, IReadOnlyList<WindowCandidate>> _descendantCandidateProvider;
    private readonly Func<IntPtr> _hostedWindowHandle;
    private readonly Func<IntPtr, int, IReadOnlyList<UiaNode>> _rootNodeProvider;
    private readonly Func<IntPtr, int, IReadOnlyList<UiaNode>> _messageSurfaceNodeProvider;

    public UiaTextCandidateDiagnosticsProvider(
        DingTalkWindowLocator windowLocator,
        UiaChatSurfaceProbe chatSurfaceProbe,
        Func<IntPtr> hostedWindowHandle)
        : this(
            windowLocator.GetWindowCandidates,
            windowLocator.GetDescendantWindowCandidates,
            hostedWindowHandle,
            chatSurfaceProbe.ProbeNodes,
            chatSurfaceProbe.ProbeMessageSurfaceNodes)
    {
        ArgumentNullException.ThrowIfNull(windowLocator);
        ArgumentNullException.ThrowIfNull(chatSurfaceProbe);
    }

    public UiaTextCandidateDiagnosticsProvider(
        Func<IReadOnlyList<WindowCandidate>> candidateProvider,
        Func<IntPtr, IReadOnlyList<WindowCandidate>> descendantCandidateProvider,
        Func<IntPtr> hostedWindowHandle,
        Func<IntPtr, int, IReadOnlyList<UiaNode>> rootNodeProvider,
        Func<IntPtr, int, IReadOnlyList<UiaNode>> messageSurfaceNodeProvider)
    {
        ArgumentNullException.ThrowIfNull(candidateProvider);
        ArgumentNullException.ThrowIfNull(descendantCandidateProvider);
        ArgumentNullException.ThrowIfNull(hostedWindowHandle);
        ArgumentNullException.ThrowIfNull(rootNodeProvider);
        ArgumentNullException.ThrowIfNull(messageSurfaceNodeProvider);

        _candidateProvider = candidateProvider;
        _descendantCandidateProvider = descendantCandidateProvider;
        _hostedWindowHandle = hostedWindowHandle;
        _rootNodeProvider = rootNodeProvider;
        _messageSurfaceNodeProvider = messageSurfaceNodeProvider;
    }

    public UiaTextCandidateDiagnosticsResult GetDiagnostics(
        int candidateLimit,
        int snapshotLimit,
        int messageSurfaceLimit,
        int minimumTextLength)
    {
        var normalizedCandidateLimit = Math.Clamp(candidateLimit, 0, MaxCandidateLimit);
        var normalizedSnapshotLimit = Math.Clamp(snapshotLimit, 0, MaxSnapshotLimit);
        var normalizedMessageSurfaceLimit = Math.Clamp(messageSurfaceLimit, 0, MaxSnapshotLimit);
        var normalizedMinimumTextLength = Math.Clamp(minimumTextLength, 1, 256);

        var hostedHandle = _hostedWindowHandle();
        var candidates = _candidateProvider();
        var descendantCandidates = hostedHandle == IntPtr.Zero
            ? Array.Empty<WindowCandidate>()
            : _descendantCandidateProvider(hostedHandle);
        var windows = BuildProbeTargets(candidates, descendantCandidates, hostedHandle)
            .Take(normalizedCandidateLimit)
            .Select(candidate => ProbeWindow(
                candidate,
                hostedHandle,
                normalizedSnapshotLimit,
                normalizedMessageSurfaceLimit,
                normalizedMinimumTextLength))
            .ToArray();
        var potentialTextCount = windows.Sum(static window => window.PotentialMessageTextCount);
        var status = potentialTextCount > 0
            ? StructuredSourceStatus.NeedsProbe
            : StructuredSourceStatus.Unavailable;

        return new UiaTextCandidateDiagnosticsResult(
            ObservedAt: DateTimeOffset.UtcNow,
            Status: status,
            Recommendation: BuildRecommendation(potentialTextCount, windows),
            HostedHwnd: FormatHandleOrEmpty(hostedHandle),
            TotalWindowCandidates: candidates.Count,
            Windows: windows);
    }

    private UiaTextCandidateWindow ProbeWindow(
        WindowCandidate candidate,
        IntPtr hostedHandle,
        int snapshotLimit,
        int messageSurfaceLimit,
        int minimumTextLength)
    {
        try
        {
            var textCandidates = CollectTextCandidates(
                    UiaTextCandidateSource.RootSnapshot,
                    _rootNodeProvider(candidate.Handle, snapshotLimit),
                    minimumTextLength)
                .Concat(CollectTextCandidates(
                    UiaTextCandidateSource.MessageSurfaceSnapshot,
                    _messageSurfaceNodeProvider(candidate.Handle, messageSurfaceLimit),
                    minimumTextLength))
                .ToArray();
            var limitedTextCandidates = textCandidates
                .Take(MaxTextCandidatesPerWindow)
                .ToArray();

            return new UiaTextCandidateWindow(
                Hwnd: FormatHandle(candidate.Handle),
                ClassName: SafePublicValue(candidate.ClassName),
                ProcessName: SafePublicValue(candidate.ProcessName),
                IsHosted: candidate.Handle == hostedHandle,
                IsVisible: candidate.IsVisible,
                IsTopLevel: candidate.IsTopLevel,
                Width: candidate.Width,
                Height: candidate.Height,
                TextCandidateCount: textCandidates.Length,
                PotentialMessageTextCount: textCandidates.Count(static item =>
                    item.IsPotentialMessageText && !item.IsLikelyNoise),
                TextCandidates: limitedTextCandidates,
                Error: string.Empty);
        }
        catch (Exception ex)
        {
            return new UiaTextCandidateWindow(
                Hwnd: FormatHandle(candidate.Handle),
                ClassName: SafePublicValue(candidate.ClassName),
                ProcessName: SafePublicValue(candidate.ProcessName),
                IsHosted: candidate.Handle == hostedHandle,
                IsVisible: candidate.IsVisible,
                IsTopLevel: candidate.IsTopLevel,
                Width: candidate.Width,
                Height: candidate.Height,
                TextCandidateCount: 0,
                PotentialMessageTextCount: 0,
                TextCandidates: Array.Empty<UiaTextCandidate>(),
                Error: ex.GetType().Name);
        }
    }

    private static IEnumerable<UiaTextCandidate> CollectTextCandidates(
        UiaTextCandidateSource source,
        IEnumerable<UiaNode> nodes,
        int minimumTextLength)
    {
        foreach (var node in nodes)
        {
            var name = NormalizeText(node.Name);
            if (name.Length < minimumTextLength)
            {
                continue;
            }

            yield return new UiaTextCandidate(
                Source: source,
                AutomationIdHash: HashValue(node.AutomationId),
                NameHash: HashValue(name),
                NameLength: name.Length,
                ControlType: SafePublicValue(node.ControlType),
                ClassName: SafePublicValue(node.ClassName),
                ClassNameHash: HashValue(node.ClassName),
                IsPotentialMessageText: IsPotentialMessageText(node, name),
                IsLikelyNoise: IsLikelyNoise(node, name));
        }
    }

    private static IReadOnlyList<WindowCandidate> BuildProbeTargets(
        IReadOnlyList<WindowCandidate> candidates,
        IReadOnlyList<WindowCandidate> descendantCandidates,
        IntPtr hostedHandle)
    {
        var byHandle = candidates.ToDictionary(static candidate => candidate.Handle);
        var emitted = new HashSet<IntPtr>();
        var targets = new List<WindowCandidate>();

        AddCandidate(hostedHandle != IntPtr.Zero && byHandle.TryGetValue(hostedHandle, out var hostedCandidate)
            ? hostedCandidate
            : CreateHostedCandidate(hostedHandle));

        foreach (var candidate in descendantCandidates
                     .Where(IsWorthProbing)
                     .OrderBy(GetProbeRank)
                     .ThenByDescending(static candidate => candidate.Area)
                     .ThenBy(static candidate => candidate.ZOrder))
        {
            AddCandidate(candidate);
        }

        foreach (var candidate in candidates
                     .Where(IsWorthProbing)
                     .OrderBy(GetProbeRank)
                     .ThenByDescending(static candidate => candidate.Area)
                     .ThenBy(static candidate => candidate.ZOrder))
        {
            AddCandidate(candidate);
        }

        return targets;

        void AddCandidate(WindowCandidate candidate)
        {
            if (candidate.Handle == IntPtr.Zero || !emitted.Add(candidate.Handle))
            {
                return;
            }

            targets.Add(candidate);
        }
    }

    private static bool IsWorthProbing(WindowCandidate candidate)
    {
        if (candidate.Handle == IntPtr.Zero
            || !candidate.IsEnabled
            || candidate.IsToolWindow
            || !DingTalkWindowLocator.IsLikelyDingTalkWindow(candidate))
        {
            return false;
        }

        return candidate.IsVisible
            || IsKnownContentClass(candidate)
            || candidate.Width >= 320
            || candidate.Height >= 240;
    }

    private static bool IsKnownContentClass(WindowCandidate candidate)
    {
        return ContentClassNames.Any(className =>
            string.Equals(candidate.ClassName, className, StringComparison.OrdinalIgnoreCase));
    }

    private static int GetProbeRank(WindowCandidate candidate)
    {
        if (string.Equals(candidate.ClassName, "DingChatWnd", StringComparison.OrdinalIgnoreCase))
        {
            return 0;
        }

        if (string.Equals(candidate.ClassName, "Chrome_RenderWidgetHostHWND", StringComparison.OrdinalIgnoreCase))
        {
            return 1;
        }

        if (string.Equals(candidate.ClassName, "CefBrowserWindow", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "Chrome_WidgetWin_1", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "QWindowContainer", StringComparison.OrdinalIgnoreCase))
        {
            return 2;
        }

        if (string.Equals(candidate.ClassName, "StandardFrame_DingTalk", StringComparison.OrdinalIgnoreCase))
        {
            return 3;
        }

        return candidate.IsVisible ? 4 : 5;
    }

    private static bool IsPotentialMessageText(UiaNode node, string text)
    {
        if (text.Length == 0 || IsLikelyNoise(node, text))
        {
            return false;
        }

        return string.Equals(node.ControlType, "Text", StringComparison.OrdinalIgnoreCase)
            || string.Equals(node.ControlType, "Edit", StringComparison.OrdinalIgnoreCase)
            || string.Equals(node.ControlType, "Document", StringComparison.OrdinalIgnoreCase)
            || string.Equals(node.ControlType, "Group", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsLikelyNoise(UiaNode node, string text)
    {
        return string.Equals(text, "DingTalk", StringComparison.OrdinalIgnoreCase)
            || string.Equals(text, "\u9489\u9489", StringComparison.OrdinalIgnoreCase)
            || string.Equals(text, "\u6d88\u606f", StringComparison.OrdinalIgnoreCase)
            || string.Equals(text, "\u6587\u6863", StringComparison.OrdinalIgnoreCase)
            || string.Equals(text, "AI \u542c\u8bb0", StringComparison.OrdinalIgnoreCase)
            || text.Contains("\u52a0\u8f7d\u4e2d", StringComparison.OrdinalIgnoreCase)
            || text.Contains("Loading", StringComparison.OrdinalIgnoreCase)
            || text.Contains("Enter/Alt+S", StringComparison.OrdinalIgnoreCase)
            || text.Contains("Ctrl+Enter", StringComparison.OrdinalIgnoreCase)
            || string.Equals(node.ControlType, "Button", StringComparison.OrdinalIgnoreCase)
            || string.Equals(node.ControlType, "TabItem", StringComparison.OrdinalIgnoreCase)
            || IsClockText(text);
    }

    private static bool IsClockText(string text)
    {
        if (text.Length is < 4 or > 5)
        {
            return false;
        }

        var separatorIndex = text.IndexOf(':', StringComparison.Ordinal);
        return separatorIndex is 1 or 2
            && int.TryParse(text[..separatorIndex], out _)
            && int.TryParse(text[(separatorIndex + 1)..], out _);
    }

    private static string NormalizeText(string value)
    {
        return string.Join(' ', value.Split(Array.Empty<char>(), StringSplitOptions.RemoveEmptyEntries));
    }

    private static string HashValue(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return string.Empty;
        }

        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();
    }

    private static string SafePublicValue(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return string.Empty;
        }

        var normalized = NormalizeText(value);
        return normalized.Length <= 96 ? normalized : normalized[..96];
    }

    private static string BuildRecommendation(
        int potentialTextCount,
        IReadOnlyList<UiaTextCandidateWindow> windows)
    {
        if (potentialTextCount > 0)
        {
            return "Passive UIA exposed text-like nodes. Correlate hashes before and after a known test message before enabling forwarding.";
        }

        if (windows.Count == 0)
        {
            return "No DingTalk HWND candidate was available for passive UIA text probing.";
        }

        return "Passive UIA did not expose usable text-like message candidates from probed DingTalk windows.";
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
