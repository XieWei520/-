using System.Diagnostics;
using System.Management;
using System.Net.Http.Json;
using DingTalkWindowsHost.Automation.WindowHost;
using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Contracts.Services;

namespace DingTalkWindowsHost.Automation.StructuredSources;

public sealed class StructuredSourceProbe : IStructuredSourceProbe
{
    private static readonly int[] CommonDevToolsPorts = { 9222, 9223 };

    private readonly Func<IReadOnlyList<WindowCandidate>> _windowCandidateSource;
    private readonly Func<IReadOnlyList<DingTalkProcessCandidate>> _processCandidateSource;
    private readonly Func<IReadOnlySet<int>> _loopbackListeningPortSource;
    private readonly Func<IReadOnlyList<LoopbackPortOwner>> _loopbackPortOwnerSource;
    private readonly Func<int, DevToolsVersionMetadata?> _devToolsVersionMetadataSource;
    private readonly Func<bool> _isOcrEnabled;

    public StructuredSourceProbe(Func<bool> isOcrEnabled)
        : this(
            GetWindowCandidates,
            GetDingTalkProcesses,
            GetLoopbackListeningPorts,
            StructuredSourceProbeSupport.GetLoopbackPortOwners,
            TryGetDevToolsVersionMetadata,
            isOcrEnabled)
    {
    }

    public StructuredSourceProbe(
        Func<IReadOnlyList<WindowCandidate>> windowCandidateSource,
        Func<IReadOnlyList<DingTalkProcessCandidate>> processCandidateSource,
        Func<IReadOnlySet<int>> loopbackListeningPortSource,
        Func<IReadOnlyList<LoopbackPortOwner>> loopbackPortOwnerSource,
        Func<int, DevToolsVersionMetadata?> devToolsVersionMetadataSource,
        Func<bool> isOcrEnabled)
    {
        ArgumentNullException.ThrowIfNull(windowCandidateSource);
        ArgumentNullException.ThrowIfNull(processCandidateSource);
        ArgumentNullException.ThrowIfNull(loopbackListeningPortSource);
        ArgumentNullException.ThrowIfNull(loopbackPortOwnerSource);
        ArgumentNullException.ThrowIfNull(devToolsVersionMetadataSource);
        ArgumentNullException.ThrowIfNull(isOcrEnabled);

        _windowCandidateSource = windowCandidateSource;
        _processCandidateSource = processCandidateSource;
        _loopbackListeningPortSource = loopbackListeningPortSource;
        _loopbackPortOwnerSource = loopbackPortOwnerSource;
        _devToolsVersionMetadataSource = devToolsVersionMetadataSource;
        _isOcrEnabled = isOcrEnabled;
    }

    public StructuredSourceProbe(
        Func<IReadOnlyList<WindowCandidate>> windowCandidateSource,
        Func<IReadOnlyList<DingTalkProcessCandidate>> processCandidateSource,
        Func<IReadOnlySet<int>> loopbackListeningPortSource,
        Func<IReadOnlyList<LoopbackPortOwner>> loopbackPortOwnerSource,
        Func<bool> isOcrEnabled)
        : this(
            windowCandidateSource,
            processCandidateSource,
            loopbackListeningPortSource,
            loopbackPortOwnerSource,
            TryGetDevToolsVersionMetadata,
            isOcrEnabled)
    {
    }

    public StructuredSourceProbe(
        Func<IReadOnlyList<WindowCandidate>> windowCandidateSource,
        Func<IReadOnlyList<DingTalkProcessCandidate>> processCandidateSource,
        Func<IReadOnlySet<int>> loopbackListeningPortSource,
        Func<int, DevToolsVersionMetadata?> devToolsVersionMetadataSource,
        Func<bool> isOcrEnabled)
        : this(
            windowCandidateSource,
            processCandidateSource,
            loopbackListeningPortSource,
            () => loopbackListeningPortSource().Select(port => new LoopbackPortOwner(port, 0)).ToArray(),
            devToolsVersionMetadataSource,
            isOcrEnabled)
    {
    }

    public StructuredSourceProbe(
        Func<IReadOnlyList<WindowCandidate>> windowCandidateSource,
        Func<IReadOnlyList<DingTalkProcessCandidate>> processCandidateSource,
        Func<IReadOnlySet<int>> loopbackListeningPortSource,
        Func<bool> isOcrEnabled)
        : this(
            windowCandidateSource,
            processCandidateSource,
            loopbackListeningPortSource,
            () => loopbackListeningPortSource().Select(port => new LoopbackPortOwner(port, 0)).ToArray(),
            TryGetDevToolsVersionMetadata,
            isOcrEnabled)
    {
    }

    public StructuredSourceProbe(
        Func<IReadOnlyList<WindowCandidate>> windowCandidateSource,
        Func<IReadOnlyList<DingTalkProcessCandidate>> processCandidateSource,
        Func<bool> isOcrEnabled)
        : this(
            windowCandidateSource,
            processCandidateSource,
            GetLoopbackListeningPorts,
            StructuredSourceProbeSupport.GetLoopbackPortOwners,
            TryGetDevToolsVersionMetadata,
            isOcrEnabled)
    {
    }

    public StructuredSourceProbeResult Probe()
    {
        var windows = _windowCandidateSource();
        var processes = _processCandidateSource();
        var loopbackListeningPorts = _loopbackListeningPortSource();
        var loopbackPortOwners = _loopbackPortOwnerSource();
        var signals = new List<StructuredSourceProbeSignal>
        {
            CreateUiAutomationSignal(windows),
            CreateEmbeddedChromiumSignal(windows),
            CreateBrowserDevToolsSignal(
                windows,
                processes,
                loopbackListeningPorts,
                loopbackPortOwners,
                _devToolsVersionMetadataSource),
            CreateNetworkCaptureSignal(processes),
            CreateLocalCacheSignal(processes),
            CreateOcrSignal(_isOcrEnabled()),
        };

        return new StructuredSourceProbeResult(
            ObservedAt: DateTimeOffset.UtcNow,
            Recommendation: BuildRecommendation(signals),
            Signals: signals);
    }

    private static StructuredSourceProbeSignal CreateUiAutomationSignal(IReadOnlyList<WindowCandidate> windows)
    {
        var hasDingTalkWindow = windows.Any(static window =>
            string.Equals(window.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase));

        return hasDingTalkWindow
            ? new StructuredSourceProbeSignal(
                StructuredSourceKind.UiAutomation,
                StructuredSourceStatus.Candidate,
                EstimatedLatencyMs: 500,
                Evidence: "DingTalk windows are visible to UI Automation probing.",
                NextAction: "Keep UIA as a low-latency trigger and metadata source.")
            : new StructuredSourceProbeSignal(
                StructuredSourceKind.UiAutomation,
                StructuredSourceStatus.NeedsProbe,
                EstimatedLatencyMs: 500,
                Evidence: "No DingTalk window candidate was found in the current session.",
                NextAction: "Start and attach DingTalk before evaluating UIA coverage.");
    }

    private static StructuredSourceProbeSignal CreateEmbeddedChromiumSignal(IReadOnlyList<WindowCandidate> windows)
    {
        var browserWindows = windows
            .Where(static window => IsEmbeddedBrowserClass(window.ClassName))
            .Take(3)
            .ToArray();

        if (browserWindows.Length == 0)
        {
            return new StructuredSourceProbeSignal(
                StructuredSourceKind.EmbeddedChromium,
                StructuredSourceStatus.NeedsProbe,
                EstimatedLatencyMs: 300,
                Evidence: "No CefBrowserWindow or Chrome_WidgetWin_* candidate is currently visible.",
                NextAction: "Attach DingTalk and inspect child windows again.");
        }

        var evidence = string.Join(
            "; ",
            browserWindows.Select(window =>
                "class="
                + window.ClassName
                + " hwnd="
                + FormatHandle(window.Handle)
                + " size="
                + window.Width
                + "x"
                + window.Height));

        return new StructuredSourceProbeSignal(
            StructuredSourceKind.EmbeddedChromium,
            StructuredSourceStatus.Candidate,
            EstimatedLatencyMs: 200,
            Evidence: evidence,
            NextAction: "Probe Chromium DevTools or DOM bridge availability before enabling OCR.");
    }

    private static StructuredSourceProbeSignal CreateBrowserDevToolsSignal(
        IReadOnlyList<WindowCandidate> windows,
        IReadOnlyList<DingTalkProcessCandidate> processes,
        IReadOnlySet<int> loopbackListeningPorts,
        IReadOnlyList<LoopbackPortOwner> loopbackPortOwners,
        Func<int, DevToolsVersionMetadata?> devToolsVersionMetadataSource)
    {
        var hasEmbeddedBrowser = windows.Any(static window => IsEmbeddedBrowserClass(window.ClassName));
        var dingTalkProcessIds = processes
            .Select(static process => process.ProcessId)
            .Where(static processId => processId > 0)
            .ToHashSet();
        var devToolsPort = processes
            .Select(process => TryGetRemoteDebuggingPort(process.CommandLine))
            .FirstOrDefault(port => port is > 0);

        if (hasEmbeddedBrowser && devToolsPort is > 0 && loopbackListeningPorts.Contains(devToolsPort.Value))
        {
            var owner = FindOwner(loopbackPortOwners, devToolsPort.Value);
            var ownership = DescribeOwnership(owner, dingTalkProcessIds);
            if (ownership == "foreign")
            {
                return new StructuredSourceProbeSignal(
                    StructuredSourceKind.BrowserDevTools,
                    StructuredSourceStatus.NeedsProbe,
                    EstimatedLatencyMs: 150,
                    Evidence: "Remote debugging port="
                        + devToolsPort.Value
                        + " ownership=foreign"
                        + FormatOwnerPid(owner)
                        + ".",
                    NextAction: "Do not use this DevTools endpoint for DingTalk; verify process ownership first.");
            }

            var metadata = devToolsVersionMetadataSource(devToolsPort.Value);
            if (metadata is not null)
            {
                return new StructuredSourceProbeSignal(
                    StructuredSourceKind.BrowserDevTools,
                    StructuredSourceStatus.Candidate,
                    EstimatedLatencyMs: 150,
                    Evidence: "DevTools-like loopback candidate detected on port="
                        + devToolsPort.Value
                        + " ownership="
                        + ownership
                        + FormatOwnerPid(owner)
                        + " versionEndpoint=ok browser="
                        + RedactMetadata(metadata.Browser)
                        + " protocol="
                        + RedactMetadata(metadata.ProtocolVersion)
                        + " websocket="
                        + metadata.HasWebSocketDebuggerUrl
                        + ". Command-line details are redacted.",
                    NextAction: "Verify target ownership before DOM observation; do not fetch page targets yet.");
            }

            return new StructuredSourceProbeSignal(
                StructuredSourceKind.BrowserDevTools,
                StructuredSourceStatus.Candidate,
                EstimatedLatencyMs: 150,
                Evidence: "DevTools-like loopback candidate detected on port="
                    + devToolsPort.Value
                    + " ownership="
                    + ownership
                    + FormatOwnerPid(owner)
                    + ". Command-line details are redacted.",
                NextAction: "Probe the DevTools version endpoint metadata only before attempting DOM observation.");
        }

        if (hasEmbeddedBrowser && devToolsPort is > 0)
        {
            var ownedMetadata = TryFindDevToolsVersionMetadataOnDingTalkOwnedPorts(
                loopbackPortOwners,
                dingTalkProcessIds,
                excludedPort: devToolsPort.Value,
                devToolsVersionMetadataSource);
            if (ownedMetadata is not null)
            {
                var owner = FindOwner(loopbackPortOwners, ownedMetadata.Port);
                return new StructuredSourceProbeSignal(
                    StructuredSourceKind.BrowserDevTools,
                    StructuredSourceStatus.Candidate,
                    EstimatedLatencyMs: 150,
                    Evidence: "Remote debugging flag references port="
                        + devToolsPort.Value
                        + ", but that port is not listening. DingTalk-owned DevTools metadata was detected on port="
                        + ownedMetadata.Port
                        + FormatOwnerPid(owner)
                        + " versionEndpoint=ok browser="
                        + RedactMetadata(ownedMetadata.Browser)
                        + " protocol="
                        + RedactMetadata(ownedMetadata.ProtocolVersion)
                        + " websocket="
                        + ownedMetadata.HasWebSocketDebuggerUrl
                        + ". Command-line details are redacted.",
                    NextAction: "Verify target ownership before DOM observation; do not fetch page targets yet.");
            }

            return new StructuredSourceProbeSignal(
                StructuredSourceKind.BrowserDevTools,
                StructuredSourceStatus.NeedsProbe,
                EstimatedLatencyMs: 150,
                Evidence: "Remote debugging flag references port="
                    + devToolsPort.Value
                    + ", but the port is not listening on loopback."
                    + FormatDingTalkOwnedLoopbackPortProbeEvidence(
                        loopbackPortOwners,
                        dingTalkProcessIds,
                        excludedPort: devToolsPort.Value),
                NextAction: "Treat DevTools as unproven for this DingTalk session; continue UIA/network metadata probing before considering OCR.");
        }

        var commonDevToolsPorts = CommonDevToolsPorts
            .Where(loopbackListeningPorts.Contains)
            .ToArray();
        if (hasEmbeddedBrowser && commonDevToolsPorts.Length > 0)
        {
            var metadata = commonDevToolsPorts
                .Select(devToolsVersionMetadataSource)
                .FirstOrDefault(static value => value is not null);
            if (metadata is not null)
            {
                var owner = FindOwner(loopbackPortOwners, metadata.Port);
                var ownership = DescribeOwnership(owner, dingTalkProcessIds);
                return new StructuredSourceProbeSignal(
                    StructuredSourceKind.BrowserDevTools,
                    ownership == "dingTalk"
                        ? StructuredSourceStatus.Candidate
                        : StructuredSourceStatus.NeedsProbe,
                    EstimatedLatencyMs: 150,
                    Evidence: "Common DevTools loopback metadata detected on port="
                        + metadata.Port
                        + " ownership="
                        + ownership
                        + FormatOwnerPid(owner)
                        + " versionEndpoint=ok browser="
                        + RedactMetadata(metadata.Browser)
                        + " protocol="
                        + RedactMetadata(metadata.ProtocolVersion)
                        + ". Ownership is not proven.",
                    NextAction: "Verify process ownership before DOM observation; do not fetch page targets yet.");
            }

            return new StructuredSourceProbeSignal(
                StructuredSourceKind.BrowserDevTools,
                StructuredSourceStatus.NeedsProbe,
                EstimatedLatencyMs: 150,
                Evidence: "Common DevTools loopback port(s) are listening: "
                    + string.Join(", ", commonDevToolsPorts.Select(static port => "port=" + port))
                    + ". Ownership is not proven.",
                NextAction: "Probe version metadata only and verify process ownership before DOM observation.");
        }

        if (hasEmbeddedBrowser
            && processes.Any(static process => !string.IsNullOrWhiteSpace(process.CommandLine)))
        {
            return new StructuredSourceProbeSignal(
                StructuredSourceKind.BrowserDevTools,
                StructuredSourceStatus.NeedsProbe,
                EstimatedLatencyMs: 150,
                Evidence: "No DingTalk command line exposes --remote-debugging-port. Command-line details are redacted.",
                NextAction: "If low-latency DOM capture is required, launch DingTalk with an explicit local remote-debugging port and verify ownership before DOM observation.");
        }

        return new StructuredSourceProbeSignal(
            StructuredSourceKind.BrowserDevTools,
            hasEmbeddedBrowser ? StructuredSourceStatus.NeedsProbe : StructuredSourceStatus.Unavailable,
            EstimatedLatencyMs: hasEmbeddedBrowser ? 150 : 0,
            Evidence: hasEmbeddedBrowser
                ? "Embedded Chromium window detected; DevTools endpoint availability is not yet proven."
                : "No embedded Chromium window detected.",
            NextAction: hasEmbeddedBrowser
                ? "Inspect DingTalk process command line and local loopback ports for DevTools candidates."
                : "Re-run after DingTalk chat UI is attached.");
    }

    private static StructuredSourceProbeSignal CreateNetworkCaptureSignal(
        IReadOnlyList<DingTalkProcessCandidate> processes)
    {
        var hasDingTalkProcess = processes.Count > 0;

        return new StructuredSourceProbeSignal(
            StructuredSourceKind.NetworkCapture,
            hasDingTalkProcess ? StructuredSourceStatus.NeedsProbe : StructuredSourceStatus.Unavailable,
            EstimatedLatencyMs: hasDingTalkProcess ? 250 : 0,
            Evidence: hasDingTalkProcess
                ? "DingTalk process exists; passive network/event capture has not been proven."
                : "No DingTalk process detected.",
            NextAction: hasDingTalkProcess
                ? "Probe safe process-level metadata only; do not intercept credentials or decrypt traffic."
                : "Start DingTalk before network source evaluation.");
    }

    private static StructuredSourceProbeSignal CreateLocalCacheSignal(
        IReadOnlyList<DingTalkProcessCandidate> processes)
    {
        return new StructuredSourceProbeSignal(
            StructuredSourceKind.LocalCacheOrLog,
            processes.Count > 0
                ? StructuredSourceStatus.NeedsManualApproval
                : StructuredSourceStatus.Unavailable,
            EstimatedLatencyMs: processes.Count > 0 ? 300 : 0,
            Evidence: processes.Count > 0
                ? "Local cache/log metadata can be discovered without reading message content; content parsing remains disabled."
                : "No DingTalk process detected.",
            NextAction: processes.Count > 0
                ? "Call /diagnostics/local-structured-sources for redacted path, type, size, and timestamp metadata only; ask again before parsing contents."
                : "Start DingTalk before considering local cache/log probing.");
    }

    private static StructuredSourceProbeSignal CreateOcrSignal(bool isEnabled)
    {
        return new StructuredSourceProbeSignal(
            StructuredSourceKind.ScreenshotOcr,
            StructuredSourceStatus.FallbackOnly,
            EstimatedLatencyMs: isEnabled ? 1500 : 0,
            Evidence: isEnabled
                ? "OCR is enabled but should remain a fallback path for low-latency targets."
                : "OCR is disabled and remains fallback-only.",
            NextAction: "Only enable cropped OCR if structured sources cannot produce message content.");
    }

    private static string BuildRecommendation(IReadOnlyList<StructuredSourceProbeSignal> signals)
    {
        if (signals.Any(static signal =>
                signal.Kind == StructuredSourceKind.BrowserDevTools
                && signal.Status == StructuredSourceStatus.Candidate))
        {
            return "Prioritize Browser DevTools metadata/DOM probing, then UIA triggers; keep OCR disabled unless all structured sources fail.";
        }

        if (signals.Any(static signal =>
                signal.Kind == StructuredSourceKind.EmbeddedChromium
                && signal.Status == StructuredSourceStatus.Candidate))
        {
            return "Prioritize Embedded Chromium DevTools/DOM probing, then UIA triggers; keep OCR disabled unless all structured sources fail.";
        }

        if (signals.Any(static signal =>
                signal.Kind == StructuredSourceKind.UiAutomation
                && signal.Status == StructuredSourceStatus.Candidate))
        {
            return "Use UIA as the trigger path and continue probing DevTools/network sources before enabling OCR.";
        }

        return "Attach DingTalk first, then evaluate UIA, Embedded Chromium DevTools, and network candidates before considering OCR.";
    }

    private static bool IsEmbeddedBrowserClass(string className)
    {
        return string.Equals(className, "CefBrowserWindow", StringComparison.OrdinalIgnoreCase)
            || className.StartsWith("Chrome_WidgetWin_", StringComparison.OrdinalIgnoreCase);
    }

    private static IReadOnlyList<WindowCandidate> GetWindowCandidates()
    {
        return new DingTalkWindowLocator().GetWindowCandidates();
    }

    private static IReadOnlyList<DingTalkProcessCandidate> GetDingTalkProcesses()
    {
        var commandLinesByProcessId = GetDingTalkCommandLinesByProcessId();
        return Process.GetProcessesByName("DingTalk")
            .Select(process =>
            {
                using (process)
                {
                    commandLinesByProcessId.TryGetValue(process.Id, out var commandLine);
                    return new DingTalkProcessCandidate(
                        ProcessId: process.Id,
                        ProcessName: process.ProcessName,
                        MainWindowHandle: process.MainWindowHandle,
                        MainWindowTitle: process.MainWindowTitle,
                        CommandLine: commandLine ?? string.Empty);
                }
            })
            .ToArray();
    }

    private static IReadOnlyDictionary<int, string> GetDingTalkCommandLinesByProcessId()
    {
        if (!OperatingSystem.IsWindows())
        {
            return new Dictionary<int, string>();
        }

        try
        {
            using var searcher = new ManagementObjectSearcher(
                "SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name = 'DingTalk.exe'");
            using var results = searcher.Get();
            var commandLines = new Dictionary<int, string>();
            foreach (ManagementObject process in results)
            {
                using (process)
                {
                    var processId = Convert.ToInt32(process["ProcessId"]);
                    var commandLine = process["CommandLine"]?.ToString() ?? string.Empty;
                    commandLines[processId] = commandLine;
                }
            }

            return commandLines;
        }
        catch (ManagementException)
        {
            return new Dictionary<int, string>();
        }
        catch (UnauthorizedAccessException)
        {
            return new Dictionary<int, string>();
        }
        catch (InvalidOperationException)
        {
            return new Dictionary<int, string>();
        }
    }

    private static IReadOnlySet<int> GetLoopbackListeningPorts()
    {
        return StructuredSourceProbeSupport.GetLoopbackPortOwners()
            .Select(static owner => owner.Port)
            .ToHashSet();
    }

    private static int? TryGetRemoteDebuggingPort(string commandLine)
    {
        if (string.IsNullOrWhiteSpace(commandLine))
        {
            return null;
        }

        const string flag = "--remote-debugging-port";
        var index = commandLine.IndexOf(flag, StringComparison.OrdinalIgnoreCase);
        if (index < 0)
        {
            return null;
        }

        var afterFlag = commandLine[(index + flag.Length)..].TrimStart();
        if (afterFlag.StartsWith("=", StringComparison.Ordinal))
        {
            afterFlag = afterFlag[1..].TrimStart();
        }

        var value = new string(afterFlag.TakeWhile(char.IsDigit).ToArray());
        return int.TryParse(value, out var port) && port is > 0 and <= 65535
            ? port
            : null;
    }

    private static DevToolsVersionMetadata? TryGetDevToolsVersionMetadata(int port)
    {
        try
        {
            using var client = new HttpClient
            {
                Timeout = TimeSpan.FromMilliseconds(300),
            };
            using var response = client
                .GetAsync("http://127.0.0.1:" + port + "/json/version")
                .GetAwaiter()
                .GetResult();
            if (!response.IsSuccessStatusCode)
            {
                return null;
            }

            var payload = response.Content
                .ReadFromJsonAsync<Dictionary<string, object?>>()
                .GetAwaiter()
                .GetResult();
            if (payload is null)
            {
                return null;
            }

            return new DevToolsVersionMetadata(
                Port: port,
                Browser: GetJsonString(payload, "Browser"),
                ProtocolVersion: GetJsonString(payload, "Protocol-Version"),
                HasWebSocketDebuggerUrl: !string.IsNullOrWhiteSpace(GetJsonString(
                    payload,
                    "webSocketDebuggerUrl")));
        }
        catch (HttpRequestException)
        {
            return null;
        }
        catch (TaskCanceledException)
        {
            return null;
        }
        catch (InvalidOperationException)
        {
            return null;
        }
    }

    private static string GetJsonString(IReadOnlyDictionary<string, object?> payload, string key)
    {
        return payload.TryGetValue(key, out var value) ? value?.ToString() ?? string.Empty : string.Empty;
    }

    private static string RedactMetadata(string value)
    {
        var compact = value.Replace("\r", string.Empty, StringComparison.Ordinal)
            .Replace("\n", string.Empty, StringComparison.Ordinal)
            .Trim();
        return compact.Length <= 80 ? compact : compact[..80];
    }

    private static LoopbackPortOwner? FindOwner(IReadOnlyList<LoopbackPortOwner> owners, int port)
    {
        return owners.FirstOrDefault(owner => owner.Port == port);
    }

    private static DevToolsVersionMetadata? TryFindDevToolsVersionMetadataOnDingTalkOwnedPorts(
        IReadOnlyList<LoopbackPortOwner> owners,
        IReadOnlySet<int> dingTalkProcessIds,
        int excludedPort,
        Func<int, DevToolsVersionMetadata?> devToolsVersionMetadataSource)
    {
        foreach (var owner in GetDingTalkOwnedLoopbackPorts(owners, dingTalkProcessIds, excludedPort))
        {
            var metadata = devToolsVersionMetadataSource(owner.Port);
            if (metadata is not null)
            {
                return metadata;
            }
        }

        return null;
    }

    private static string FormatDingTalkOwnedLoopbackPortProbeEvidence(
        IReadOnlyList<LoopbackPortOwner> owners,
        IReadOnlySet<int> dingTalkProcessIds,
        int excludedPort)
    {
        var ownedPorts = GetDingTalkOwnedLoopbackPorts(owners, dingTalkProcessIds, excludedPort);
        if (ownedPorts.Count == 0)
        {
            return " No DingTalk-owned loopback listener was observed.";
        }

        return " DingTalk-owned loopback listener(s) probed with /json/version: "
            + string.Join(
                "; ",
                ownedPorts.Select(owner => "port=" + owner.Port + FormatOwnerPid(owner)))
            + "; no DevTools version endpoint was proven.";
    }

    private static IReadOnlyList<LoopbackPortOwner> GetDingTalkOwnedLoopbackPorts(
        IReadOnlyList<LoopbackPortOwner> owners,
        IReadOnlySet<int> dingTalkProcessIds,
        int excludedPort)
    {
        return owners
            .Where(owner => owner.Port > 0
                && owner.Port != excludedPort
                && owner.ProcessId > 0
                && dingTalkProcessIds.Contains(owner.ProcessId))
            .GroupBy(static owner => owner.Port)
            .Select(static group => group.First())
            .OrderBy(static owner => owner.Port)
            .Take(5)
            .ToArray();
    }

    private static string DescribeOwnership(
        LoopbackPortOwner? owner,
        IReadOnlySet<int> dingTalkProcessIds)
    {
        if (owner is null || owner.ProcessId <= 0)
        {
            return "unknown";
        }

        return dingTalkProcessIds.Contains(owner.ProcessId) ? "dingTalk" : "foreign";
    }

    private static string FormatOwnerPid(LoopbackPortOwner? owner)
    {
        return owner is null || owner.ProcessId <= 0 ? string.Empty : " ownerPid=" + owner.ProcessId;
    }

    private static string FormatHandle(IntPtr handle)
    {
        return handle == IntPtr.Zero ? string.Empty : "0x" + handle.ToInt64().ToString("X");
    }
}
