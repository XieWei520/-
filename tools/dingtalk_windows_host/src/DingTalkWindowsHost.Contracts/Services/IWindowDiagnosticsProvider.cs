using DingTalkWindowsHost.Contracts.Models;

namespace DingTalkWindowsHost.Contracts.Services;

public interface IWindowDiagnosticsProvider
{
    IReadOnlyList<string> GetCandidateSummary(int limit);

    WindowCandidateDiagnosticsResult GetCandidateDiagnostics(int limit);
}
