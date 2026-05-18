using DingTalkWindowsHost.Automation.StructuredSources;
using DingTalkWindowsHost.Automation.WindowHost;
using DingTalkWindowsHost.Contracts.Models;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class StructuredSourceProbeTests
{
    [Fact]
    public void Probe_recommends_chromium_devtools_when_embedded_browser_windows_exist()
    {
        var probe = new StructuredSourceProbe(
            windowCandidateSource: static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x101),
                    Title: string.Empty,
                    ClassName: "CefBrowserWindow",
                    IsVisible: true,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 1200,
                    Height: 700,
                    ZOrder: 1,
                    ProcessName: "DingTalk"),
            },
            processCandidateSource: static () => new[]
            {
                new DingTalkProcessCandidate(
                    ProcessId: 1001,
                    ProcessName: "DingTalk",
                    MainWindowHandle: new IntPtr(0x201),
                    MainWindowTitle: "\u9489\u9489"),
            },
            isOcrEnabled: static () => false);

        var result = probe.Probe();

        Assert.Contains(
            result.Signals,
            signal => signal.Kind == StructuredSourceKind.EmbeddedChromium
                && signal.Status == StructuredSourceStatus.Candidate
                && signal.EstimatedLatencyMs <= 500);
        Assert.Contains("DevTools", result.Recommendation, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Probe_marks_ocr_as_fallback_and_reports_when_disabled()
    {
        var probe = new StructuredSourceProbe(
            windowCandidateSource: static () => Array.Empty<WindowCandidate>(),
            processCandidateSource: static () => Array.Empty<DingTalkProcessCandidate>(),
            isOcrEnabled: static () => false);

        var result = probe.Probe();

        Assert.Contains(
            result.Signals,
            signal => signal.Kind == StructuredSourceKind.ScreenshotOcr
                && signal.Status == StructuredSourceStatus.FallbackOnly
                && signal.Evidence.Contains("disabled", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void Probe_keeps_local_storage_manual_approval_only()
    {
        var probe = new StructuredSourceProbe(
            windowCandidateSource: static () => Array.Empty<WindowCandidate>(),
            processCandidateSource: static () => new[]
            {
                new DingTalkProcessCandidate(
                    ProcessId: 1001,
                    ProcessName: "DingTalk",
                    MainWindowHandle: IntPtr.Zero,
                    MainWindowTitle: string.Empty),
            },
            isOcrEnabled: static () => false);

        var result = probe.Probe();

        Assert.Contains(
            result.Signals,
            signal => signal.Kind == StructuredSourceKind.LocalCacheOrLog
                && signal.Status == StructuredSourceStatus.NeedsManualApproval
                && signal.NextAction.Contains("/diagnostics/local-structured-sources", StringComparison.Ordinal));
    }

    [Fact]
    public void Probe_marks_devtools_candidate_when_remote_debugging_port_is_listening()
    {
        var probe = new StructuredSourceProbe(
            windowCandidateSource: static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x301),
                    Title: string.Empty,
                    ClassName: "CefBrowserWindow",
                    IsVisible: true,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 1200,
                    Height: 700,
                    ZOrder: 1,
                    ProcessName: "DingTalk"),
            },
            processCandidateSource: static () => new[]
            {
                new DingTalkProcessCandidate(
                    ProcessId: 1001,
                    ProcessName: "DingTalk",
                    MainWindowHandle: new IntPtr(0x201),
                    MainWindowTitle: string.Empty,
                    CommandLine: "DingTalk.exe --remote-debugging-port=9222 --access_token=secret"),
            },
            loopbackListeningPortSource: static () => new HashSet<int> { 9222 },
            isOcrEnabled: static () => false);

        var result = probe.Probe();

        var signal = Assert.Single(
            result.Signals,
            signal => signal.Kind == StructuredSourceKind.BrowserDevTools);
        Assert.Equal(StructuredSourceStatus.Candidate, signal.Status);
        Assert.Contains("port=9222", signal.Evidence, StringComparison.Ordinal);
        Assert.DoesNotContain("secret", signal.Evidence, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("DevTools", result.Recommendation, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Probe_does_not_mark_devtools_candidate_when_remote_debugging_port_is_not_listening()
    {
        var probe = new StructuredSourceProbe(
            windowCandidateSource: static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x401),
                    Title: string.Empty,
                    ClassName: "Chrome_WidgetWin_1",
                    IsVisible: true,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 1200,
                    Height: 700,
                    ZOrder: 1,
                    ProcessName: "DingTalk"),
            },
            processCandidateSource: static () => new[]
            {
                new DingTalkProcessCandidate(
                    ProcessId: 1001,
                    ProcessName: "DingTalk",
                    MainWindowHandle: IntPtr.Zero,
                    MainWindowTitle: string.Empty,
                    CommandLine: "DingTalk.exe --remote-debugging-port=9223"),
            },
            loopbackListeningPortSource: static () => new HashSet<int> { 9222 },
            isOcrEnabled: static () => false);

        var result = probe.Probe();

        var signal = Assert.Single(
            result.Signals,
            signal => signal.Kind == StructuredSourceKind.BrowserDevTools);
        Assert.Equal(StructuredSourceStatus.NeedsProbe, signal.Status);
        Assert.Contains("not listening", signal.Evidence, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Probe_reports_dingtalk_owned_loopback_ports_when_requested_devtools_port_is_not_listening()
    {
        var probedPorts = new List<int>();
        var probe = new StructuredSourceProbe(
            windowCandidateSource: static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x451),
                    Title: string.Empty,
                    ClassName: "Chrome_WidgetWin_0",
                    IsVisible: true,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 1200,
                    Height: 700,
                    ZOrder: 1,
                    ProcessName: "DingTalk"),
            },
            processCandidateSource: static () => new[]
            {
                new DingTalkProcessCandidate(
                    ProcessId: 1001,
                    ProcessName: "DingTalk",
                    MainWindowHandle: IntPtr.Zero,
                    MainWindowTitle: string.Empty,
                    CommandLine: "DingTalk.exe --remote-debugging-port=9222"),
            },
            loopbackListeningPortSource: static () => new HashSet<int> { 8440, 62910 },
            loopbackPortOwnerSource: static () => new[]
            {
                new LoopbackPortOwner(Port: 8440, ProcessId: 1001),
                new LoopbackPortOwner(Port: 62910, ProcessId: 1001),
            },
            devToolsVersionMetadataSource: port =>
            {
                probedPorts.Add(port);
                return null;
            },
            isOcrEnabled: static () => false);

        var result = probe.Probe();

        var signal = Assert.Single(
            result.Signals,
            signal => signal.Kind == StructuredSourceKind.BrowserDevTools);
        Assert.Equal(StructuredSourceStatus.NeedsProbe, signal.Status);
        Assert.Equal(new[] { 8440, 62910 }, probedPorts);
        Assert.Contains("port=9222", signal.Evidence, StringComparison.Ordinal);
        Assert.Contains("port=8440 ownerPid=1001", signal.Evidence, StringComparison.Ordinal);
        Assert.Contains("port=62910 ownerPid=1001", signal.Evidence, StringComparison.Ordinal);
        Assert.Contains("/json/version", signal.Evidence, StringComparison.Ordinal);
    }

    [Fact]
    public void Probe_reports_common_loopback_devtools_port_as_needs_probe_without_claiming_candidate()
    {
        var probe = new StructuredSourceProbe(
            windowCandidateSource: static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x501),
                    Title: string.Empty,
                    ClassName: "CefBrowserWindow",
                    IsVisible: true,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 1200,
                    Height: 700,
                    ZOrder: 1,
                    ProcessName: "DingTalk"),
            },
            processCandidateSource: static () => new[]
            {
                new DingTalkProcessCandidate(
                    ProcessId: 1001,
                    ProcessName: "DingTalk",
                    MainWindowHandle: IntPtr.Zero,
                    MainWindowTitle: string.Empty),
            },
            loopbackListeningPortSource: static () => new HashSet<int> { 9222 },
            isOcrEnabled: static () => false);

        var result = probe.Probe();

        var signal = Assert.Single(
            result.Signals,
            signal => signal.Kind == StructuredSourceKind.BrowserDevTools);
        Assert.Equal(StructuredSourceStatus.NeedsProbe, signal.Status);
        Assert.Contains("9222", signal.Evidence, StringComparison.Ordinal);
    }

    [Fact]
    public void Probe_reports_when_command_line_was_checked_without_remote_debugging_flag()
    {
        var probe = new StructuredSourceProbe(
            windowCandidateSource: static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x551),
                    Title: string.Empty,
                    ClassName: "CefBrowserWindow",
                    IsVisible: true,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 1200,
                    Height: 700,
                    ZOrder: 1,
                    ProcessName: "DingTalk"),
            },
            processCandidateSource: static () => new[]
            {
                new DingTalkProcessCandidate(
                    ProcessId: 1001,
                    ProcessName: "DingTalk",
                    MainWindowHandle: IntPtr.Zero,
                    MainWindowTitle: string.Empty,
                    CommandLine: "DingTalk.exe --type=renderer --user-data-dir=C:\\Users\\secret"),
            },
            loopbackListeningPortSource: static () => new HashSet<int>(),
            isOcrEnabled: static () => false);

        var result = probe.Probe();

        var signal = Assert.Single(
            result.Signals,
            signal => signal.Kind == StructuredSourceKind.BrowserDevTools);
        Assert.Equal(StructuredSourceStatus.NeedsProbe, signal.Status);
        Assert.Contains("No DingTalk command line exposes --remote-debugging-port", signal.Evidence, StringComparison.Ordinal);
        Assert.DoesNotContain("secret", signal.Evidence, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Probe_includes_devtools_version_metadata_without_fetching_page_targets()
    {
        var probedPorts = new List<int>();
        var probe = new StructuredSourceProbe(
            windowCandidateSource: static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x601),
                    Title: string.Empty,
                    ClassName: "CefBrowserWindow",
                    IsVisible: true,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 1200,
                    Height: 700,
                    ZOrder: 1,
                    ProcessName: "DingTalk"),
            },
            processCandidateSource: static () => new[]
            {
                new DingTalkProcessCandidate(
                    ProcessId: 1001,
                    ProcessName: "DingTalk",
                    MainWindowHandle: IntPtr.Zero,
                    MainWindowTitle: string.Empty,
                    CommandLine: "DingTalk.exe --remote-debugging-port=9222"),
            },
            loopbackListeningPortSource: static () => new HashSet<int> { 9222 },
            devToolsVersionMetadataSource: port =>
            {
                probedPorts.Add(port);
                return new DevToolsVersionMetadata(
                    Port: port,
                    Browser: "Chrome/120.0",
                    ProtocolVersion: "1.3",
                    HasWebSocketDebuggerUrl: true);
            },
            isOcrEnabled: static () => false);

        var result = probe.Probe();

        Assert.Equal(new[] { 9222 }, probedPorts);
        var signal = Assert.Single(
            result.Signals,
            signal => signal.Kind == StructuredSourceKind.BrowserDevTools);
        Assert.Equal(StructuredSourceStatus.Candidate, signal.Status);
        Assert.Contains("versionEndpoint=ok", signal.Evidence, StringComparison.Ordinal);
        Assert.Contains("protocol=1.3", signal.Evidence, StringComparison.Ordinal);
        Assert.DoesNotContain("json/list", signal.Evidence, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Probe_marks_devtools_candidate_only_when_port_owner_is_dingtalk_process()
    {
        var probe = new StructuredSourceProbe(
            windowCandidateSource: static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x701),
                    Title: string.Empty,
                    ClassName: "CefBrowserWindow",
                    IsVisible: true,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 1200,
                    Height: 700,
                    ZOrder: 1,
                    ProcessName: "DingTalk"),
            },
            processCandidateSource: static () => new[]
            {
                new DingTalkProcessCandidate(
                    ProcessId: 1001,
                    ProcessName: "DingTalk",
                    MainWindowHandle: IntPtr.Zero,
                    MainWindowTitle: string.Empty,
                    CommandLine: "DingTalk.exe --remote-debugging-port=9222"),
            },
            loopbackListeningPortSource: static () => new HashSet<int> { 9222 },
            loopbackPortOwnerSource: static () => new[]
            {
                new LoopbackPortOwner(Port: 9222, ProcessId: 1001),
            },
            devToolsVersionMetadataSource: static port => new DevToolsVersionMetadata(
                Port: port,
                Browser: "Chrome/120.0",
                ProtocolVersion: "1.3",
                HasWebSocketDebuggerUrl: true),
            isOcrEnabled: static () => false);

        var result = probe.Probe();

        var signal = Assert.Single(
            result.Signals,
            signal => signal.Kind == StructuredSourceKind.BrowserDevTools);
        Assert.Equal(StructuredSourceStatus.Candidate, signal.Status);
        Assert.Contains("ownerPid=1001", signal.Evidence, StringComparison.Ordinal);
        Assert.Contains("ownership=dingTalk", signal.Evidence, StringComparison.Ordinal);
    }

    [Fact]
    public void Probe_keeps_devtools_needs_probe_when_port_owner_is_not_dingtalk_process()
    {
        var probe = new StructuredSourceProbe(
            windowCandidateSource: static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x801),
                    Title: string.Empty,
                    ClassName: "CefBrowserWindow",
                    IsVisible: true,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 1200,
                    Height: 700,
                    ZOrder: 1,
                    ProcessName: "DingTalk"),
            },
            processCandidateSource: static () => new[]
            {
                new DingTalkProcessCandidate(
                    ProcessId: 1001,
                    ProcessName: "DingTalk",
                    MainWindowHandle: IntPtr.Zero,
                    MainWindowTitle: string.Empty,
                    CommandLine: "DingTalk.exe --remote-debugging-port=9222"),
            },
            loopbackListeningPortSource: static () => new HashSet<int> { 9222 },
            loopbackPortOwnerSource: static () => new[]
            {
                new LoopbackPortOwner(Port: 9222, ProcessId: 2002),
            },
            devToolsVersionMetadataSource: static port => new DevToolsVersionMetadata(
                Port: port,
                Browser: "Chrome/120.0",
                ProtocolVersion: "1.3",
                HasWebSocketDebuggerUrl: true),
            isOcrEnabled: static () => false);

        var result = probe.Probe();

        var signal = Assert.Single(
            result.Signals,
            signal => signal.Kind == StructuredSourceKind.BrowserDevTools);
        Assert.Equal(StructuredSourceStatus.NeedsProbe, signal.Status);
        Assert.Contains("ownership=foreign", signal.Evidence, StringComparison.Ordinal);
    }
}
