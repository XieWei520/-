using System.Diagnostics;
using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Contracts.Services;

namespace DingTalkWindowsHost.Automation.WindowHost;

public sealed record DingTalkLauncherOptions(
    string LauncherPath,
    int RemoteDebuggingPort,
    bool EnableRendererAccessibility)
{
    public static DingTalkLauncherOptions FromEnvironment()
    {
        return Create(
            Environment.GetEnvironmentVariable("DINGTALK_HOST_LAUNCHER") ?? string.Empty,
            Environment.GetEnvironmentVariable("DINGTALK_HOST_REMOTE_DEBUGGING_PORT"),
            Environment.GetEnvironmentVariable("DINGTALK_HOST_ENABLE_RENDERER_ACCESSIBILITY"),
            DiscoverLauncherPathFromRunningProcess);
    }

    internal static DingTalkLauncherOptions Create(
        string configuredLauncherPath,
        string? configuredRemoteDebuggingPort,
        string? configuredRendererAccessibility,
        Func<string> discoverLauncherPath)
    {
        var discoveredPath = discoverLauncherPath();
        return new DingTalkLauncherOptions(
            string.IsNullOrWhiteSpace(configuredLauncherPath)
                ? ResolvePreferredLauncherPath(discoveredPath)
                : configuredLauncherPath,
            ParseRemoteDebuggingPort(configuredRemoteDebuggingPort),
            ParseBoolean(configuredRendererAccessibility));
    }

    private static int ParseRemoteDebuggingPort(string? value)
    {
        return int.TryParse(value, out var port) && port is > 0 and <= 65535
            ? port
            : 0;
    }

    private static bool ParseBoolean(string? value)
    {
        return string.Equals(value, "1", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "true", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "yes", StringComparison.OrdinalIgnoreCase);
    }

    private static string DiscoverLauncherPathFromRunningProcess()
    {
        foreach (var process in Process.GetProcessesByName("DingTalk"))
        {
            using (process)
            {
                try
                {
                    if (!string.IsNullOrWhiteSpace(process.MainModule?.FileName)
                        && File.Exists(process.MainModule.FileName))
                    {
                        return process.MainModule.FileName;
                    }
                }
                catch (Exception ex) when (ex is InvalidOperationException or System.ComponentModel.Win32Exception)
                {
                }
            }
        }

        return string.Empty;
    }

    private static string ResolvePreferredLauncherPath(string discoveredPath)
    {
        if (string.IsNullOrWhiteSpace(discoveredPath))
        {
            return string.Empty;
        }

        var directory = Path.GetDirectoryName(discoveredPath);
        while (!string.IsNullOrWhiteSpace(directory))
        {
            var launcherPath = Path.Combine(directory, "DingtalkLauncher.exe");
            if (File.Exists(launcherPath))
            {
                return launcherPath;
            }

            directory = Directory.GetParent(directory)?.FullName;
        }

        return discoveredPath;
    }
}

public sealed record DingTalkLaunchProcessRequest(string FileName, string Arguments);

public sealed record DingTalkRunningProcess(int ProcessId, Action Stop);

public sealed class DingTalkLauncher : IDingTalkLauncher
{
    private readonly DingTalkLauncherOptions _options;
    private readonly Func<IReadOnlyList<DingTalkRunningProcess>> _runningProcessSource;
    private readonly Action<DingTalkLaunchProcessRequest> _startProcess;

    public DingTalkLauncher(DingTalkLauncherOptions options)
        : this(options, StartDetachedProcess, EnumerateRunningProcesses)
    {
    }

    public DingTalkLauncher(DingTalkLauncherOptions options, Action<DingTalkLaunchProcessRequest> startProcess)
        : this(options, startProcess, EnumerateRunningProcesses)
    {
    }

    public DingTalkLauncher(
        DingTalkLauncherOptions options,
        Action<DingTalkLaunchProcessRequest> startProcess,
        Func<IReadOnlyList<DingTalkRunningProcess>> runningProcessSource)
    {
        ArgumentNullException.ThrowIfNull(options);
        ArgumentNullException.ThrowIfNull(startProcess);
        ArgumentNullException.ThrowIfNull(runningProcessSource);

        _options = options;
        _startProcess = startProcess;
        _runningProcessSource = runningProcessSource;
    }

    public DingTalkLauncherDiagnosticsResult GetDiagnostics()
    {
        var isConfigured = !string.IsNullOrWhiteSpace(_options.LauncherPath);
        var pathExists = isConfigured && File.Exists(_options.LauncherPath);
        var readiness = !isConfigured
            ? DingTalkLauncherReadiness.NotConfigured
            : pathExists
                ? DingTalkLauncherReadiness.Ready
                : DingTalkLauncherReadiness.NotFound;

        return new DingTalkLauncherDiagnosticsResult(
            Readiness: readiness,
            IsConfigured: isConfigured,
            PathExists: pathExists,
            RemoteDebuggingPort: _options.RemoteDebuggingPort,
            RendererAccessibilityEnabled: _options.EnableRendererAccessibility,
            LauncherPath: _options.LauncherPath,
            Recommendation: BuildRecommendation(
                readiness,
                _options.RemoteDebuggingPort,
                _options.EnableRendererAccessibility),
            ObservedAt: DateTimeOffset.UtcNow);
    }

    public DingTalkLaunchResult Launch()
    {
        return LaunchCore(restarted: false);
    }

    public DingTalkLaunchResult Restart()
    {
        var attemptedAt = DateTimeOffset.UtcNow;
        try
        {
            foreach (var process in _runningProcessSource())
            {
                process.Stop();
            }
        }
        catch (Exception ex) when (ex is InvalidOperationException or System.ComponentModel.Win32Exception)
        {
            return new DingTalkLaunchResult(
                Status: DingTalkLaunchStatus.Failed,
                Message: "Failed to stop existing DingTalk process before restart: " + ex.Message,
                LauncherPath: _options.LauncherPath,
                AttemptedAt: attemptedAt);
        }

        return LaunchCore(restarted: true);
    }

    private DingTalkLaunchResult LaunchCore(bool restarted)
    {
        var attemptedAt = DateTimeOffset.UtcNow;
        if (string.IsNullOrWhiteSpace(_options.LauncherPath))
        {
            return new DingTalkLaunchResult(
                Status: DingTalkLaunchStatus.NotConfigured,
                Message: "DingTalk launcher path is not configured. Set DINGTALK_HOST_LAUNCHER.",
                LauncherPath: string.Empty,
                AttemptedAt: attemptedAt);
        }

        if (!File.Exists(_options.LauncherPath))
        {
            return new DingTalkLaunchResult(
                Status: DingTalkLaunchStatus.NotFound,
                Message: "Configured DingTalk launcher path does not exist.",
                LauncherPath: _options.LauncherPath,
                AttemptedAt: attemptedAt);
        }

        try
        {
            var launchPath = ResolveLaunchPath(_options.LauncherPath, _options.RemoteDebuggingPort);
            _startProcess(new DingTalkLaunchProcessRequest(
                FileName: launchPath,
                Arguments: BuildLaunchArguments(_options)));
            return new DingTalkLaunchResult(
                Status: DingTalkLaunchStatus.Started,
                Message: BuildLaunchMessage(_options.LauncherPath, launchPath, restarted),
                LauncherPath: _options.LauncherPath,
                AttemptedAt: attemptedAt);
        }
        catch (Exception ex) when (ex is InvalidOperationException or System.ComponentModel.Win32Exception)
        {
            return new DingTalkLaunchResult(
                Status: DingTalkLaunchStatus.Failed,
                Message: "Failed to invoke DingTalk launcher: " + ex.Message,
            LauncherPath: _options.LauncherPath,
            AttemptedAt: attemptedAt);
        }
    }

    private static string BuildLaunchMessage(string launcherPath, string launchPath, bool restarted)
    {
        if (restarted)
        {
            return "DingTalk was restarted explicitly and launched"
                + (Path.GetFileName(launchPath).Equals("DingTalk.exe", StringComparison.OrdinalIgnoreCase)
                    ? " directly for remote debugging."
                    : " through the configured launcher.");
        }

        return launchPath == launcherPath
            ? "DingTalk launcher was invoked."
            : "DingTalk was launched directly for remote debugging.";
    }

    private static IReadOnlyList<DingTalkRunningProcess> EnumerateRunningProcesses()
    {
        return Process.GetProcessesByName("DingTalk")
            .Select(static process =>
            {
                var processId = process.Id;
                process.Dispose();
                return new DingTalkRunningProcess(processId, () => StopProcessById(processId));
            })
            .ToArray();
    }

    private static void StopProcessById(int processId)
    {
        try
        {
            using var process = Process.GetProcessById(processId);
            if (process.HasExited)
            {
                return;
            }

            if (process.MainWindowHandle != IntPtr.Zero)
            {
                _ = process.CloseMainWindow();
                if (process.WaitForExit(3000))
                {
                    return;
                }
            }

            process.Kill(entireProcessTree: true);
            process.WaitForExit(5000);
        }
        catch (ArgumentException)
        {
        }
    }

    private static string ResolveLaunchPath(string launcherPath, int remoteDebuggingPort)
    {
        if (remoteDebuggingPort <= 0)
        {
            return launcherPath;
        }

        if (string.Equals(Path.GetFileName(launcherPath), "DingTalk.exe", StringComparison.OrdinalIgnoreCase))
        {
            return launcherPath;
        }

        var launcherDirectory = Path.GetDirectoryName(launcherPath);
        if (string.IsNullOrWhiteSpace(launcherDirectory))
        {
            throw new InvalidOperationException(
                "Remote debugging launch was requested, but DingTalk.exe could not be resolved from the configured launcher path.");
        }

        var directExecutablePath = Path.Combine(launcherDirectory, "main", "current", "DingTalk.exe");
        if (File.Exists(directExecutablePath))
        {
            return directExecutablePath;
        }

        var siblingExecutablePath = Path.Combine(launcherDirectory, "DingTalk.exe");
        if (File.Exists(siblingExecutablePath))
        {
            return siblingExecutablePath;
        }

        throw new InvalidOperationException(
            "Remote debugging launch was requested, but DingTalk.exe could not be resolved from the configured launcher path.");
    }

    private static void StartDetachedProcess(DingTalkLaunchProcessRequest request)
    {
        using var process = Process.Start(new ProcessStartInfo
        {
            FileName = request.FileName,
            Arguments = request.Arguments,
            UseShellExecute = true,
            WorkingDirectory = Path.GetDirectoryName(request.FileName) ?? string.Empty,
        });
    }

    private static string BuildLaunchArguments(DingTalkLauncherOptions options)
    {
        var arguments = new List<string>();
        if (options.RemoteDebuggingPort > 0)
        {
            arguments.Add("--remote-debugging-port="
                + options.RemoteDebuggingPort.ToString(System.Globalization.CultureInfo.InvariantCulture));
        }

        if (options.EnableRendererAccessibility)
        {
            arguments.Add("--force-renderer-accessibility");
        }

        return string.Join(" ", arguments);
    }

    private static string BuildRecommendation(
        DingTalkLauncherReadiness readiness,
        int remoteDebuggingPort,
        bool rendererAccessibilityEnabled)
    {
        var recommendation = readiness switch
        {
            DingTalkLauncherReadiness.Ready => "DingTalk launcher is ready for explicit operator launch.",
            DingTalkLauncherReadiness.NotConfigured =>
                "Set DINGTALK_HOST_LAUNCHER to the installed DingtalkLauncher.exe path.",
            DingTalkLauncherReadiness.NotFound =>
                "Configured DingTalk launcher path does not exist. Update DINGTALK_HOST_LAUNCHER.",
            _ => "Inspect DingTalk launcher configuration.",
        };

        if (readiness != DingTalkLauncherReadiness.Ready)
        {
            return recommendation;
        }

        if (remoteDebuggingPort > 0)
        {
            recommendation += " Remote debugging launch is explicitly configured; verify loopback ownership before DOM probing.";
        }

        if (rendererAccessibilityEnabled)
        {
            recommendation += " Renderer accessibility is explicitly configured; verify UIA exposes message text before enabling OCR.";
        }

        return recommendation;
    }
}
