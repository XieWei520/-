using System.Windows.Forms;
using System.Runtime.InteropServices;
using System.Drawing;
using FlaUI.Core.Input;
using FlaUI.Core.WindowsAPI;
using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Contracts.Services;

namespace DingTalkWindowsHost.Automation.Capture;

public sealed class ClipboardMessageProbe : IClipboardMessageProbe
{
    private const string SourceConversationId = "windows:clipboard-active";
    private const string SourceConversationName = "(clipboard active chat)";
    private const uint CfUnicodeText = 13;
    private static int _restoreInFlight;
    private readonly ClipboardMessageProbeOptions _options;

    public ClipboardMessageProbe(ClipboardMessageProbeOptions options)
    {
        ArgumentNullException.ThrowIfNull(options);
        _options = options;
    }

    public ExtractedClipboardMessage? ProbeLatest(IntPtr windowHandle)
    {
        if (!_options.Enabled || windowHandle == IntPtr.Zero)
        {
            return null;
        }

        return RunOnStaThread(progress => ProbeLatestOnStaThread(windowHandle, progress).Message).Value;
    }

    public ClipboardMessageProbeDiagnosticsResult GetDiagnostics(IntPtr windowHandle)
    {
        if (!_options.Enabled)
        {
            return new ClipboardMessageProbeDiagnosticsResult(
                ObservedAt: DateTimeOffset.UtcNow,
                Enabled: false,
                TargetHwnd: FormatHandle(windowHandle),
                Status: "Disabled",
                ClipboardChanged: false,
                CopiedTextLength: 0,
                CopiedTextHash: string.Empty,
                ExtractedTextLength: 0,
                ExtractedTextHash: string.Empty,
                SourceConversationIdHint: string.Empty,
                Error: string.Empty);
        }

        var result = RunOnStaThread(progress => ProbeLatestOnStaThread(windowHandle, progress).Diagnostics);
        return result.Value
            ?? new ClipboardMessageProbeDiagnosticsResult(
                ObservedAt: DateTimeOffset.UtcNow,
                Enabled: true,
                TargetHwnd: FormatHandle(windowHandle),
                Status: "Failed",
                ClipboardChanged: false,
                CopiedTextLength: 0,
                CopiedTextHash: string.Empty,
                ExtractedTextLength: 0,
                ExtractedTextHash: string.Empty,
                SourceConversationIdHint: string.Empty,
                Error: BuildStaThreadFailureError(result.Failure, result.TimedOut, result.LastStage));
    }

    private static ClipboardProbeResult ProbeLatestOnStaThread(
        IntPtr windowHandle,
        Action<string> reportStage)
    {
        reportStage("activate-window");
        var focused = TryActivateWindow(windowHandle);

        reportStage("read-original-clipboard");
        var originalClipboardText = SafeGetClipboardText();
        var sentinelText = "__DINGTALK_HOST_CLIPBOARD_PROBE__"
            + Guid.NewGuid().ToString("N");
        try
        {
            reportStage("set-sentinel");
            SafeSetClipboardText(sentinelText);
            reportStage("click-message-surface");
            TryClickMessageSurface(windowHandle);
            Thread.Sleep(120);
            reportStage("select-message-surface");
            TryTypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.KEY_A);
            Thread.Sleep(80);
            reportStage("copy-message-surface");
            TryTypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.KEY_C);
            Thread.Sleep(160);

            reportStage("read-copied-clipboard");
            var copiedText = SafeGetClipboardText() ?? string.Empty;
            var latestText = ClipboardMessageTextExtractor.TryExtractLatest(copiedText, sentinelText);
            var clipboardChanged = !string.Equals(copiedText, sentinelText, StringComparison.Ordinal);
            var message = string.IsNullOrWhiteSpace(latestText)
                ? null
                : new ExtractedClipboardMessage(
                    SourceConversationName: SourceConversationName,
                    SenderName: string.Empty,
                    Text: latestText,
                    ObservedAt: DateTimeOffset.UtcNow,
                    SourceConversationIdHint: SourceConversationId);
            return new ClipboardProbeResult(
                Message: message,
                Diagnostics: new ClipboardMessageProbeDiagnosticsResult(
                    ObservedAt: DateTimeOffset.UtcNow,
                    Enabled: true,
                    TargetHwnd: FormatHandle(windowHandle),
                    Status: message is null ? "NoMessageText" : "Extracted",
                    ClipboardChanged: clipboardChanged,
                    CopiedTextLength: copiedText.Length,
                    CopiedTextHash: Sha256Prefix(copiedText),
                    ExtractedTextLength: latestText?.Length ?? 0,
                    ExtractedTextHash: string.IsNullOrWhiteSpace(latestText)
                        ? string.Empty
                        : Sha256Prefix(latestText),
                    SourceConversationIdHint: message?.SourceConversationIdHint ?? string.Empty,
                    Error: focused ? string.Empty : "set-foreground-failed"));
        }
        finally
        {
            TryQueueClipboardRestore(originalClipboardText);
        }
    }

    internal static string BuildStaThreadFailureError(Exception? failure, bool timedOut)
    {
        return BuildStaThreadFailureError(failure, timedOut, string.Empty);
    }

    internal static string BuildStaThreadFailureError(Exception? failure, bool timedOut, string lastStage)
    {
        var suffix = string.IsNullOrWhiteSpace(lastStage)
            ? string.Empty
            : " stage='" + SanitizeDiagnosticValue(lastStage) + "'";
        if (timedOut)
        {
            return "clipboard-probe-thread-timeout" + suffix;
        }

        if (failure is null)
        {
            return "clipboard-probe-thread-failed" + suffix;
        }

        return "clipboard-probe-thread-failed type='"
            + failure.GetType().Name
            + "' hresult='0x"
            + failure.HResult.ToString("X8")
            + "'"
            + suffix;
    }

    private static StaThreadResult<T> RunOnStaThread<T>(Func<Action<string>, T?> action)
        where T : class
    {
        T? result = null;
        Exception? failure = null;
        var lastStage = "not-started";
        var thread = new Thread(() =>
        {
            try
            {
                result = action(stage => lastStage = stage);
            }
            catch (Exception ex)
            {
                failure = ex;
            }
        });
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        thread.Join(TimeSpan.FromSeconds(5));
        return new StaThreadResult<T>(
            Value: thread.IsAlive || failure is not null ? null : result,
            Failure: failure,
            TimedOut: thread.IsAlive,
            LastStage: lastStage);
    }

    private static string SanitizeDiagnosticValue(string value)
    {
        return value.Replace("'", string.Empty, StringComparison.Ordinal)
            .Replace("\r", string.Empty, StringComparison.Ordinal)
            .Replace("\n", string.Empty, StringComparison.Ordinal);
    }

    private static string Sha256Prefix(string value)
    {
        if (string.IsNullOrEmpty(value))
        {
            return string.Empty;
        }

        var bytes = System.Security.Cryptography.SHA256.HashData(
            System.Text.Encoding.UTF8.GetBytes(value));
        return Convert.ToHexString(bytes).ToLowerInvariant()[..12];
    }

    private static string FormatHandle(IntPtr handle)
    {
        return "0x" + handle.ToInt64().ToString("X");
    }

    private static void TryClickMessageSurface(IntPtr windowHandle)
    {
        if (!NativeMethods.GetWindowRect(windowHandle, out var rect))
        {
            return;
        }

        var width = rect.Right - rect.Left;
        var height = rect.Bottom - rect.Top;
        if (width <= 0 || height <= 0)
        {
            return;
        }

        if (TryBuildMessageSurfaceClickPoint(new Rectangle(rect.Left, rect.Top, width, height), out var point))
        {
            TryLeftClick(point);
        }
    }

    internal static bool TryBuildMessageSurfaceClickPoint(Rectangle bounds, out Point point)
    {
        point = default;
        if (bounds.Width <= 0 || bounds.Height <= 0)
        {
            return false;
        }

        var xOffset = Math.Clamp(bounds.Width * 2 / 3, 1, bounds.Width - 1);
        var yOffset = Math.Clamp(bounds.Height / 2, 1, bounds.Height - 1);
        point = new Point(bounds.Left + xOffset, bounds.Top + yOffset);
        return true;
    }

    private static void TryScrollMessageSurfaceToBottom()
    {
        TryMouseScroll(-8);
        try
        {
            Keyboard.Type(VirtualKeyShort.END);
            Thread.Sleep(60);
            Keyboard.Type(VirtualKeyShort.NEXT);
        }
        catch (Exception)
        {
        }
    }

    private static void TryMouseScroll(double clicks)
    {
        try
        {
            Mouse.Scroll(clicks);
        }
        catch (Exception)
        {
        }
    }

    private static void TryLeftClick(Point point)
    {
        try
        {
            Mouse.LeftClick(point);
        }
        catch (Exception)
        {
        }
    }

    private static void TryTypeSimultaneously(params VirtualKeyShort[] keys)
    {
        try
        {
            Keyboard.TypeSimultaneously(keys);
        }
        catch (Exception)
        {
        }
    }

    internal static IReadOnlyList<IntPtr> BuildActivationTargets(
        IntPtr windowHandle,
        Func<IntPtr, IntPtr> parentProvider,
        Func<IntPtr, IntPtr> rootProvider)
    {
        var targets = new List<IntPtr>();
        AddActivationTarget(targets, windowHandle);
        AddActivationTarget(targets, parentProvider(windowHandle));
        AddActivationTarget(targets, rootProvider(windowHandle));
        return targets;
    }

    internal static bool ShouldRestoreClipboardTextForTests(string? originalClipboardText)
    {
        return ShouldRestoreClipboardText(originalClipboardText);
    }

    internal static string? TryReadUnicodeClipboardTextForTests(
        IntPtr clipboardDataHandle,
        Func<IntPtr, IntPtr> lockGlobalMemory,
        Func<IntPtr, IntPtr> unlockGlobalMemory,
        Func<IntPtr, bool> hasUnicodeClipboardFormat)
    {
        ArgumentNullException.ThrowIfNull(lockGlobalMemory);
        ArgumentNullException.ThrowIfNull(unlockGlobalMemory);
        ArgumentNullException.ThrowIfNull(hasUnicodeClipboardFormat);

        if (clipboardDataHandle == IntPtr.Zero || !hasUnicodeClipboardFormat(clipboardDataHandle))
        {
            return null;
        }

        var textPointer = lockGlobalMemory(clipboardDataHandle);
        if (textPointer == IntPtr.Zero)
        {
            return null;
        }

        try
        {
            return Marshal.PtrToStringUni(textPointer);
        }
        finally
        {
            _ = unlockGlobalMemory(clipboardDataHandle);
        }
    }

    private static bool TryActivateWindow(IntPtr windowHandle)
    {
        foreach (var target in BuildActivationTargets(
                     windowHandle,
                     NativeMethods.GetParent,
                     handle => NativeMethods.GetAncestor(handle, NativeMethods.GaRoot)))
        {
            if (NativeMethods.SetForegroundWindow(target))
            {
                return true;
            }
        }

        return false;
    }

    private static void AddActivationTarget(List<IntPtr> targets, IntPtr handle)
    {
        if (handle != IntPtr.Zero && !targets.Contains(handle))
        {
            targets.Add(handle);
        }
    }

    private static string? SafeGetClipboardText()
    {
        if (!NativeMethods.OpenClipboard(IntPtr.Zero))
        {
            return null;
        }

        try
        {
            return TryReadUnicodeClipboardTextForTests(
                NativeMethods.GetClipboardData(CfUnicodeText),
                NativeMethods.GlobalLock,
                NativeMethods.GlobalUnlock,
                _ => NativeMethods.IsClipboardFormatAvailable(CfUnicodeText));
        }
        catch (ArgumentException)
        {
            return string.Empty;
        }
        finally
        {
            _ = NativeMethods.CloseClipboard();
        }
    }

    private static void SafeSetClipboardText(string text)
    {
        try
        {
            Clipboard.SetText(text, TextDataFormat.UnicodeText);
        }
        catch (ArgumentException)
        {
        }
        catch (ExternalException)
        {
        }
        catch (ThreadStateException)
        {
        }
    }

    private static void SafeClearClipboard()
    {
        try
        {
            Clipboard.Clear();
        }
        catch (ExternalException)
        {
        }
        catch (ThreadStateException)
        {
        }
    }

    private static bool TryQueueClipboardRestore(string? originalClipboardText)
    {
        if (Interlocked.Exchange(ref _restoreInFlight, 1) == 1)
        {
            return false;
        }

        try
        {
            var thread = new Thread(() =>
            {
                try
                {
                    var restoreText = originalClipboardText ?? string.Empty;
                    if (ShouldRestoreClipboardText(restoreText))
                    {
                        SafeSetClipboardText(restoreText);
                    }
                    else
                    {
                        SafeClearClipboard();
                    }
                }
                finally
                {
                    Interlocked.Exchange(ref _restoreInFlight, 0);
                }
            });
            thread.SetApartmentState(ApartmentState.STA);
            thread.IsBackground = true;
            thread.Start();
            return true;
        }
        catch (ThreadStateException)
        {
            Interlocked.Exchange(ref _restoreInFlight, 0);
            return false;
        }
        catch (OutOfMemoryException)
        {
            Interlocked.Exchange(ref _restoreInFlight, 0);
            return false;
        }
    }

    private static bool ShouldRestoreClipboardText(string? originalClipboardText)
    {
        return !string.IsNullOrEmpty(originalClipboardText);
    }

    private static class NativeMethods
    {
        [System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
        internal static extern bool SetForegroundWindow(IntPtr hWnd);

        [System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
        internal static extern IntPtr GetParent(IntPtr hWnd);

        [System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
        internal static extern IntPtr GetAncestor(IntPtr hWnd, uint gaFlags);

        [System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
        internal static extern bool GetWindowRect(IntPtr hWnd, out WindowRect lpRect);

        [System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
        internal static extern bool OpenClipboard(IntPtr hWndNewOwner);

        [System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
        internal static extern bool CloseClipboard();

        [System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
        internal static extern bool IsClipboardFormatAvailable(uint format);

        [System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
        internal static extern IntPtr GetClipboardData(uint format);

        [System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true)]
        internal static extern IntPtr GlobalLock(IntPtr hMem);

        [System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true)]
        internal static extern IntPtr GlobalUnlock(IntPtr hMem);

        internal const uint GaRoot = 2;
    }

    [StructLayout(LayoutKind.Sequential)]
    private readonly struct WindowRect
    {
        public readonly int Left;
        public readonly int Top;
        public readonly int Right;
        public readonly int Bottom;
    }

    private sealed record ClipboardProbeResult(
        ExtractedClipboardMessage? Message,
        ClipboardMessageProbeDiagnosticsResult Diagnostics)
    {
        public static ClipboardProbeResult Failed(IntPtr windowHandle, string error)
        {
            return new ClipboardProbeResult(
                Message: null,
                Diagnostics: new ClipboardMessageProbeDiagnosticsResult(
                    ObservedAt: DateTimeOffset.UtcNow,
                    Enabled: true,
                    TargetHwnd: FormatHandle(windowHandle),
                    Status: "Failed",
                    ClipboardChanged: false,
                    CopiedTextLength: 0,
                    CopiedTextHash: string.Empty,
                    ExtractedTextLength: 0,
                    ExtractedTextHash: string.Empty,
                    SourceConversationIdHint: string.Empty,
                    Error: error));
        }
    }

    private sealed record StaThreadResult<T>(
        T? Value,
        Exception? Failure,
        bool TimedOut,
        string LastStage)
        where T : class;
}
