using DingTalkWindowsHost.Automation.WindowHost;
using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Contracts.Services;

namespace DingTalkWindowsHost.Automation.Capture;

public sealed class FallbackWindowScreenshotService : IWindowScreenshotService
{
    private readonly IWindowScreenshotService _inner;
    private readonly DingTalkWindowLocator _windowLocator;

    public FallbackWindowScreenshotService(
        IWindowScreenshotService inner,
        DingTalkWindowLocator windowLocator)
    {
        ArgumentNullException.ThrowIfNull(inner);
        ArgumentNullException.ThrowIfNull(windowLocator);

        _inner = inner;
        _windowLocator = windowLocator;
    }

    public async Task<WindowScreenshotResult?> CaptureAsync(
        IntPtr windowHandle,
        CancellationToken cancellationToken)
    {
        var screenshot = await _inner.CaptureAsync(windowHandle, cancellationToken);
        if (screenshot is not null)
        {
            return screenshot;
        }

        foreach (var candidate in GetFallbackCandidates(windowHandle))
        {
            screenshot = await _inner.CaptureAsync(candidate.Handle, cancellationToken);
            if (screenshot is not null)
            {
                return screenshot;
            }
        }

        return null;
    }

    public async Task<WindowScreenshotResult?> CaptureChatAreaAsync(
        IntPtr windowHandle,
        CancellationToken cancellationToken)
    {
        var screenshot = await _inner.CaptureChatAreaAsync(windowHandle, cancellationToken);
        if (screenshot is not null)
        {
            return screenshot;
        }

        foreach (var candidate in GetFallbackCandidates(windowHandle))
        {
            screenshot = await _inner.CaptureChatAreaAsync(candidate.Handle, cancellationToken);
            if (screenshot is not null)
            {
                return screenshot;
            }
        }

        return null;
    }

    internal IReadOnlyList<WindowCandidate> GetFallbackCandidates(IntPtr currentWindowHandle)
    {
        var candidates = _windowLocator.GetWindowCandidates();
        var descendantCandidates = currentWindowHandle == IntPtr.Zero
            ? Array.Empty<WindowCandidate>()
            : _windowLocator.GetDescendantWindowCandidates(currentWindowHandle);

        return BuildFallbackCandidates(candidates, descendantCandidates, currentWindowHandle)
            .ToArray();
    }

    internal static IEnumerable<WindowCandidate> BuildFallbackCandidates(
        IEnumerable<WindowCandidate> desktopCandidates,
        IEnumerable<WindowCandidate> descendantCandidates,
        IntPtr currentWindowHandle)
    {
        var emitted = new HashSet<IntPtr>();
        foreach (var candidate in descendantCandidates
                     .Concat(desktopCandidates)
                     .Where(candidate => IsScreenshotFallbackCandidate(candidate, currentWindowHandle))
                     .OrderBy(GetScreenshotFallbackRank)
                     .ThenByDescending(static candidate => candidate.Area)
                     .ThenBy(static candidate => candidate.ZOrder))
        {
            if (emitted.Add(candidate.Handle))
            {
                yield return candidate;
            }
        }
    }

    private static bool IsScreenshotFallbackCandidate(
        WindowCandidate candidate,
        IntPtr currentWindowHandle)
    {
        if (candidate.Handle == IntPtr.Zero
            || candidate.Handle == currentWindowHandle
            || !candidate.IsEnabled
            || candidate.IsToolWindow
            || !string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
            || DingTalkTransientOverlayClassifier.IsTransientOverlay(candidate)
            || candidate.Width < 320
            || candidate.Height < 240)
        {
            return false;
        }

        return IsKnownContentCandidate(candidate)
            || (candidate.IsVisible && !candidate.IsTopLevel);
    }

    private static bool IsKnownContentCandidate(WindowCandidate candidate)
    {
        return string.Equals(candidate.Title, "DTIMContentModule", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.Title, "DTIMChatModule", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "DingChatWnd", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "CefBrowserWindow", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "Chrome_WidgetWin_0", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "Chrome_WidgetWin_1", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "Chrome_RenderWidgetHostHWND", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "QWindowContainer", StringComparison.OrdinalIgnoreCase);
    }

    private static int GetScreenshotFallbackRank(WindowCandidate candidate)
    {
        if (string.Equals(candidate.Title, "DTIMContentModule", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.Title, "DTIMChatModule", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "DingChatWnd", StringComparison.OrdinalIgnoreCase))
        {
            return 0;
        }

        if (string.Equals(candidate.ClassName, "CefBrowserWindow", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "Chrome_WidgetWin_1", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "Chrome_RenderWidgetHostHWND", StringComparison.OrdinalIgnoreCase))
        {
            return 1;
        }

        if (string.Equals(candidate.ClassName, "Chrome_WidgetWin_0", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "QWindowContainer", StringComparison.OrdinalIgnoreCase))
        {
            return 2;
        }

        return 3;
    }
}
