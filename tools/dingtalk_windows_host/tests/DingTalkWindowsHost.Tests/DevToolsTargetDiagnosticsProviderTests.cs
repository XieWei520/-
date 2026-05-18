using DingTalkWindowsHost.Automation.StructuredSources;
using DingTalkWindowsHost.Contracts.Models;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class DevToolsTargetDiagnosticsProviderTests
{
    [Fact]
    public void GetDiagnostics_fetches_targets_only_when_devtools_port_is_owned_by_dingtalk()
    {
        var listedPorts = new List<int>();
        var provider = new DevToolsTargetDiagnosticsProvider(
            processCandidateSource: static () => new[]
            {
                new DingTalkProcessCandidate(
                    ProcessId: 1001,
                    ProcessName: "DingTalk",
                    MainWindowHandle: IntPtr.Zero,
                    MainWindowTitle: string.Empty,
                    CommandLine: "DingTalk.exe --remote-debugging-port=9222"),
            },
            loopbackPortOwnerSource: static () => new[]
            {
                new LoopbackPortOwner(Port: 9222, ProcessId: 1001),
            },
            versionMetadataSource: static port => new DevToolsVersionMetadata(
                Port: port,
                Browser: "Chrome/120.0",
                ProtocolVersion: "1.3",
                HasWebSocketDebuggerUrl: true),
            targetMetadataSource: port =>
            {
                listedPorts.Add(port);
                return new[]
                {
                    new DevToolsTargetMetadata(
                        Id: "page-1",
                        Type: "page",
                        Title: "DingTalk",
                        Url: "https://example.invalid/chat",
                        HasWebSocketDebuggerUrl: true),
                };
            });

        var result = provider.GetDiagnostics();

        Assert.Equal(StructuredSourceStatus.Candidate, result.Status);
        Assert.Equal(9222, result.Port);
        Assert.Equal(1001, result.OwnerProcessId);
        Assert.Equal(new[] { 9222 }, listedPorts);
        var target = Assert.Single(result.Targets);
        Assert.Equal("page", target.Type);
        Assert.Contains("target metadata", result.Recommendation, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void GetDiagnostics_does_not_fetch_targets_when_port_owner_is_foreign()
    {
        var listedPorts = new List<int>();
        var provider = new DevToolsTargetDiagnosticsProvider(
            processCandidateSource: static () => new[]
            {
                new DingTalkProcessCandidate(
                    ProcessId: 1001,
                    ProcessName: "DingTalk",
                    MainWindowHandle: IntPtr.Zero,
                    MainWindowTitle: string.Empty,
                    CommandLine: "DingTalk.exe --remote-debugging-port=9222"),
            },
            loopbackPortOwnerSource: static () => new[]
            {
                new LoopbackPortOwner(Port: 9222, ProcessId: 2002),
            },
            versionMetadataSource: static port => new DevToolsVersionMetadata(
                Port: port,
                Browser: "Chrome/120.0",
                ProtocolVersion: "1.3",
                HasWebSocketDebuggerUrl: true),
            targetMetadataSource: port =>
            {
                listedPorts.Add(port);
                return Array.Empty<DevToolsTargetMetadata>();
            });

        var result = provider.GetDiagnostics();

        Assert.Equal(StructuredSourceStatus.NeedsProbe, result.Status);
        Assert.Empty(listedPorts);
        Assert.Empty(result.Targets);
        Assert.Contains("ownership", result.Recommendation, StringComparison.OrdinalIgnoreCase);
    }
}
