using System.Diagnostics;
using System.Management;
using System.Net.Http.Json;
using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Contracts.Services;

namespace DingTalkWindowsHost.Automation.StructuredSources;

public sealed class DevToolsTargetDiagnosticsProvider : IDevToolsTargetDiagnosticsProvider
{
    private readonly Func<IReadOnlyList<DingTalkProcessCandidate>> _processCandidateSource;
    private readonly Func<IReadOnlyList<LoopbackPortOwner>> _loopbackPortOwnerSource;
    private readonly Func<int, DevToolsVersionMetadata?> _versionMetadataSource;
    private readonly Func<int, IReadOnlyList<DevToolsTargetMetadata>> _targetMetadataSource;

    public DevToolsTargetDiagnosticsProvider()
        : this(
            GetDingTalkProcesses,
            StructuredSourceProbeSupport.GetLoopbackPortOwners,
            TryGetVersionMetadata,
            TryGetTargetMetadata)
    {
    }

    public DevToolsTargetDiagnosticsProvider(
        Func<IReadOnlyList<DingTalkProcessCandidate>> processCandidateSource,
        Func<IReadOnlyList<LoopbackPortOwner>> loopbackPortOwnerSource,
        Func<int, DevToolsVersionMetadata?> versionMetadataSource,
        Func<int, IReadOnlyList<DevToolsTargetMetadata>> targetMetadataSource)
    {
        ArgumentNullException.ThrowIfNull(processCandidateSource);
        ArgumentNullException.ThrowIfNull(loopbackPortOwnerSource);
        ArgumentNullException.ThrowIfNull(versionMetadataSource);
        ArgumentNullException.ThrowIfNull(targetMetadataSource);

        _processCandidateSource = processCandidateSource;
        _loopbackPortOwnerSource = loopbackPortOwnerSource;
        _versionMetadataSource = versionMetadataSource;
        _targetMetadataSource = targetMetadataSource;
    }

    public DevToolsTargetDiagnosticsResult GetDiagnostics()
    {
        var processes = _processCandidateSource();
        var dingTalkProcessIds = processes
            .Select(static process => process.ProcessId)
            .Where(static processId => processId > 0)
            .ToHashSet();
        var remoteDebuggingPort = processes
            .Select(static process => TryGetRemoteDebuggingPort(process.CommandLine))
            .FirstOrDefault(static port => port is > 0);
        if (remoteDebuggingPort is null)
        {
            return Create(
                StructuredSourceStatus.NeedsProbe,
                port: 0,
                ownerProcessId: 0,
                "No DingTalk process exposes --remote-debugging-port; target metadata was not fetched.",
                Array.Empty<DevToolsTargetMetadata>());
        }

        var owner = _loopbackPortOwnerSource()
            .FirstOrDefault(portOwner => portOwner.Port == remoteDebuggingPort.Value);
        if (owner is null || !dingTalkProcessIds.Contains(owner.ProcessId))
        {
            return Create(
                StructuredSourceStatus.NeedsProbe,
                remoteDebuggingPort.Value,
                owner?.ProcessId ?? 0,
                "DevTools target metadata was not fetched because loopback port ownership is not proven for DingTalk.",
                Array.Empty<DevToolsTargetMetadata>());
        }

        var version = _versionMetadataSource(remoteDebuggingPort.Value);
        if (version is null)
        {
            return Create(
                StructuredSourceStatus.NeedsProbe,
                remoteDebuggingPort.Value,
                owner.ProcessId,
                "DevTools target metadata was not fetched because /json/version was not available.",
                Array.Empty<DevToolsTargetMetadata>());
        }

        var targets = _targetMetadataSource(remoteDebuggingPort.Value);
        return Create(
            StructuredSourceStatus.Candidate,
            remoteDebuggingPort.Value,
            owner.ProcessId,
            "DingTalk-owned DevTools target metadata is available; inspect target titles/types before any DOM observation.",
            targets);
    }

    private static DevToolsTargetDiagnosticsResult Create(
        StructuredSourceStatus status,
        int port,
        int ownerProcessId,
        string recommendation,
        IReadOnlyList<DevToolsTargetMetadata> targets)
    {
        return new DevToolsTargetDiagnosticsResult(
            ObservedAt: DateTimeOffset.UtcNow,
            Status: status,
            Port: port,
            OwnerProcessId: ownerProcessId,
            Recommendation: recommendation,
            Targets: targets);
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

    private static DevToolsVersionMetadata? TryGetVersionMetadata(int port)
    {
        try
        {
            using var client = CreateHttpClient();
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

    private static IReadOnlyList<DevToolsTargetMetadata> TryGetTargetMetadata(int port)
    {
        try
        {
            using var client = CreateHttpClient();
            var payload = client
                .GetFromJsonAsync<IReadOnlyList<Dictionary<string, object?>>>(
                    "http://127.0.0.1:" + port + "/json/list")
                .GetAwaiter()
                .GetResult();
            return payload is null
                ? Array.Empty<DevToolsTargetMetadata>()
                : payload
                    .Take(20)
                    .Select(static target => new DevToolsTargetMetadata(
                        Id: GetJsonString(target, "id"),
                        Type: GetJsonString(target, "type"),
                        Title: GetJsonString(target, "title"),
                        Url: RedactUrl(GetJsonString(target, "url")),
                        HasWebSocketDebuggerUrl: !string.IsNullOrWhiteSpace(GetJsonString(
                            target,
                            "webSocketDebuggerUrl"))))
                    .ToArray();
        }
        catch (HttpRequestException)
        {
            return Array.Empty<DevToolsTargetMetadata>();
        }
        catch (TaskCanceledException)
        {
            return Array.Empty<DevToolsTargetMetadata>();
        }
        catch (InvalidOperationException)
        {
            return Array.Empty<DevToolsTargetMetadata>();
        }
    }

    private static HttpClient CreateHttpClient()
    {
        return new HttpClient
        {
            Timeout = TimeSpan.FromMilliseconds(300),
        };
    }

    private static string GetJsonString(IReadOnlyDictionary<string, object?> payload, string key)
    {
        return payload.TryGetValue(key, out var value) ? value?.ToString() ?? string.Empty : string.Empty;
    }

    private static string RedactUrl(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return string.Empty;
        }

        if (!Uri.TryCreate(value, UriKind.Absolute, out var uri))
        {
            return value.Length <= 160 ? value : value[..160];
        }

        return uri.GetLeftPart(UriPartial.Path);
    }
}
