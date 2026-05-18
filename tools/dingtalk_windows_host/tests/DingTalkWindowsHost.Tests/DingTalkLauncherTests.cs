using DingTalkWindowsHost.Automation.WindowHost;
using DingTalkWindowsHost.Contracts.Models;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class DingTalkLauncherTests
{
    [Fact]
    public void Launch_returns_not_configured_when_launcher_path_is_empty()
    {
        var launcher = new DingTalkLauncher(new DingTalkLauncherOptions("", 0, false), static _ => { });

        var result = launcher.Launch();

        Assert.Equal(DingTalkLaunchStatus.NotConfigured, result.Status);
        Assert.Contains("DINGTALK_HOST_LAUNCHER", result.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Launch_returns_not_found_when_launcher_path_does_not_exist()
    {
        var launcher = new DingTalkLauncher(
            new DingTalkLauncherOptions(@"Z:\missing\DingtalkLauncher.exe", 0, false),
            static _ => { });

        var result = launcher.Launch();

        Assert.Equal(DingTalkLaunchStatus.NotFound, result.Status);
        Assert.Contains("does not exist", result.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Launch_invokes_process_starter_when_configured_path_exists()
    {
        var launched = new List<string>();
        var launcher = new DingTalkLauncher(
            new DingTalkLauncherOptions(Environment.ProcessPath ?? "dotnet", 0, false),
            request => launched.Add(request.FileName + "|" + request.Arguments));

        var result = launcher.Launch();

        Assert.Equal(DingTalkLaunchStatus.Started, result.Status);
        Assert.Single(launched);
    }

    [Fact]
    public void Restart_stops_running_dingtalk_processes_before_launching()
    {
        var root = Path.Combine(Path.GetTempPath(), "dingtalk-restart-debug-test-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        var directExecutablePath = Path.Combine(root, "DingTalk.exe");
        var stopped = new List<int>();
        var launched = new List<DingTalkLaunchProcessRequest>();
        try
        {
            File.WriteAllText(directExecutablePath, "");
            var launcher = new DingTalkLauncher(
                new DingTalkLauncherOptions(directExecutablePath, 9222, false),
                launched.Add,
                () => new[]
                {
                    new DingTalkRunningProcess(101, () => stopped.Add(101)),
                    new DingTalkRunningProcess(102, () => stopped.Add(102)),
                });

            var result = launcher.Restart();

            Assert.Equal(DingTalkLaunchStatus.Started, result.Status);
            Assert.Equal(new[] { 101, 102 }, stopped);
            Assert.Single(launched);
            Assert.Contains("--remote-debugging-port=9222", launched[0].Arguments, StringComparison.Ordinal);
            Assert.Contains("restarted", result.Message, StringComparison.OrdinalIgnoreCase);
        }
        finally
        {
            if (Directory.Exists(root))
            {
                Directory.Delete(root, recursive: true);
            }
        }
    }

    [Fact]
    public void Restart_reports_failed_when_stopping_process_throws()
    {
        var launcher = new DingTalkLauncher(
            new DingTalkLauncherOptions(Environment.ProcessPath ?? "dotnet", 0, false),
            static _ => { },
            static () => new[]
            {
                new DingTalkRunningProcess(101, static () => throw new InvalidOperationException("stop failed")),
            });

        var result = launcher.Restart();

        Assert.Equal(DingTalkLaunchStatus.Failed, result.Status);
        Assert.Contains("stop failed", result.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Launch_passes_remote_debugging_port_when_explicitly_configured()
    {
        var root = Path.Combine(Path.GetTempPath(), "dingtalk-direct-debug-test-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        var directExecutablePath = Path.Combine(root, "DingTalk.exe");
        try
        {
            File.WriteAllText(directExecutablePath, "");

            var launched = new List<DingTalkLaunchProcessRequest>();
            var launcher = new DingTalkLauncher(
                new DingTalkLauncherOptions(directExecutablePath, 9222, false),
                launched.Add);

            var result = launcher.Launch();

            Assert.Equal(DingTalkLaunchStatus.Started, result.Status);
            var request = Assert.Single(launched);
            Assert.Equal(directExecutablePath, request.FileName);
            Assert.Contains("--remote-debugging-port=9222", request.Arguments, StringComparison.Ordinal);
            Assert.DoesNotContain("9222", result.Message, StringComparison.Ordinal);
        }
        finally
        {
            if (Directory.Exists(root))
            {
                Directory.Delete(root, recursive: true);
            }
        }
    }

    [Fact]
    public void Launch_uses_direct_dingtalk_executable_when_remote_debugging_is_requested()
    {
        var root = Path.Combine(Path.GetTempPath(), "dingtalk-launcher-debug-test-" + Guid.NewGuid().ToString("N"));
        var current = Path.Combine(root, "main", "current");
        Directory.CreateDirectory(current);
        var launcherPath = Path.Combine(root, "DingtalkLauncher.exe");
        var directExecutablePath = Path.Combine(current, "DingTalk.exe");
        try
        {
            File.WriteAllText(launcherPath, "");
            File.WriteAllText(directExecutablePath, "");

            var launched = new List<DingTalkLaunchProcessRequest>();
            var launcher = new DingTalkLauncher(
                new DingTalkLauncherOptions(launcherPath, 9222, false),
                launched.Add);

            var result = launcher.Launch();

            Assert.Equal(DingTalkLaunchStatus.Started, result.Status);
            var request = Assert.Single(launched);
            Assert.Equal(directExecutablePath, request.FileName);
            Assert.Contains("--remote-debugging-port=9222", request.Arguments, StringComparison.Ordinal);
        }
        finally
        {
            if (Directory.Exists(root))
            {
                Directory.Delete(root, recursive: true);
            }
        }
    }

    [Fact]
    public void GetDiagnostics_reports_ready_when_configured_path_exists()
    {
        var launcher = new DingTalkLauncher(
            new DingTalkLauncherOptions(Environment.ProcessPath ?? "dotnet", 0, false),
            static _ => { });

        var diagnostics = launcher.GetDiagnostics();

        Assert.Equal(DingTalkLauncherReadiness.Ready, diagnostics.Readiness);
        Assert.True(diagnostics.IsConfigured);
        Assert.True(diagnostics.PathExists);
        Assert.Equal(0, diagnostics.RemoteDebuggingPort);
        Assert.Contains("ready", diagnostics.Recommendation, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void GetDiagnostics_reports_remote_debugging_when_configured()
    {
        var launcher = new DingTalkLauncher(
            new DingTalkLauncherOptions(Environment.ProcessPath ?? "dotnet", 9222, false),
            static _ => { });

        var diagnostics = launcher.GetDiagnostics();

        Assert.Equal(DingTalkLauncherReadiness.Ready, diagnostics.Readiness);
        Assert.Equal(9222, diagnostics.RemoteDebuggingPort);
        Assert.Contains("remote debugging", diagnostics.Recommendation, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void GetDiagnostics_reports_not_configured_without_path()
    {
        var launcher = new DingTalkLauncher(new DingTalkLauncherOptions("", 0, false), static _ => { });

        var diagnostics = launcher.GetDiagnostics();

        Assert.Equal(DingTalkLauncherReadiness.NotConfigured, diagnostics.Readiness);
        Assert.False(diagnostics.IsConfigured);
        Assert.False(diagnostics.PathExists);
        Assert.Contains("DINGTALK_HOST_LAUNCHER", diagnostics.Recommendation, StringComparison.Ordinal);
    }

    [Fact]
    public void Options_can_discover_launcher_from_running_dingtalk_process_path()
    {
        var processPath = Environment.ProcessPath ?? "dotnet";

        var options = DingTalkLauncherOptions.Create(
            configuredLauncherPath: "",
            configuredRemoteDebuggingPort: "",
            configuredRendererAccessibility: "",
            discoverLauncherPath: () => processPath);

        Assert.Equal(processPath, options.LauncherPath);
    }

    [Fact]
    public void Options_prefers_sibling_dingtalk_launcher_over_process_executable()
    {
        var root = Path.Combine(Path.GetTempPath(), "dingtalk-launcher-test-" + Guid.NewGuid().ToString("N"));
        var current = Path.Combine(root, "main", "current");
        Directory.CreateDirectory(current);
        var processPath = Path.Combine(current, "DingTalk.exe");
        var launcherPath = Path.Combine(root, "DingtalkLauncher.exe");
        try
        {
            File.WriteAllText(processPath, "");
            File.WriteAllText(launcherPath, "");

            var options = DingTalkLauncherOptions.Create(
                configuredLauncherPath: "",
                configuredRemoteDebuggingPort: "",
                configuredRendererAccessibility: "",
                discoverLauncherPath: () => processPath);

            Assert.Equal(launcherPath, options.LauncherPath);
        }
        finally
        {
            if (Directory.Exists(root))
            {
                Directory.Delete(root, recursive: true);
            }
        }
    }

    [Fact]
    public void Options_prefers_configured_launcher_over_discovered_path()
    {
        var configuredPath = Environment.ProcessPath ?? "dotnet";

        var options = DingTalkLauncherOptions.Create(
            configuredLauncherPath: configuredPath,
            configuredRemoteDebuggingPort: "9222",
            configuredRendererAccessibility: "true",
            discoverLauncherPath: () => @"Z:\ignored\DingTalk.exe");

        Assert.Equal(configuredPath, options.LauncherPath);
        Assert.Equal(9222, options.RemoteDebuggingPort);
        Assert.True(options.EnableRendererAccessibility);
    }

    [Fact]
    public void Launch_passes_renderer_accessibility_when_explicitly_configured()
    {
        var launched = new List<DingTalkLaunchProcessRequest>();
        var launcher = new DingTalkLauncher(
            new DingTalkLauncherOptions(Environment.ProcessPath ?? "dotnet", 0, true),
            launched.Add);

        var result = launcher.Launch();

        Assert.Equal(DingTalkLaunchStatus.Started, result.Status);
        var request = Assert.Single(launched);
        Assert.Contains("--force-renderer-accessibility", request.Arguments, StringComparison.Ordinal);
    }

    [Fact]
    public void GetDiagnostics_reports_renderer_accessibility_when_configured()
    {
        var launcher = new DingTalkLauncher(
            new DingTalkLauncherOptions(Environment.ProcessPath ?? "dotnet", 0, true),
            static _ => { });

        var diagnostics = launcher.GetDiagnostics();

        Assert.True(diagnostics.RendererAccessibilityEnabled);
        Assert.Contains("Renderer accessibility", diagnostics.Recommendation, StringComparison.Ordinal);
    }
}
