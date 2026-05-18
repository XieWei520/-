using DingTalkWindowsHost.Contracts.Models;

namespace DingTalkWindowsHost.Contracts.Services;

public interface IUiaTextCandidateDiagnosticsProvider
{
    UiaTextCandidateDiagnosticsResult GetDiagnostics(
        int candidateLimit,
        int snapshotLimit,
        int messageSurfaceLimit,
        int minimumTextLength);
}
