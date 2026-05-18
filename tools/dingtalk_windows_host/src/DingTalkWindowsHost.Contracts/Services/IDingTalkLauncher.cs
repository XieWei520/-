using DingTalkWindowsHost.Contracts.Models;

namespace DingTalkWindowsHost.Contracts.Services;

public interface IDingTalkLauncher
{
    DingTalkLauncherDiagnosticsResult GetDiagnostics();

    DingTalkLaunchResult Launch();

    DingTalkLaunchResult Restart();
}
