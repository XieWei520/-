using DingTalkWindowsHost.Contracts.Models;

namespace DingTalkWindowsHost.Contracts.Services;

public interface IDevToolsTargetDiagnosticsProvider
{
    DevToolsTargetDiagnosticsResult GetDiagnostics();
}
