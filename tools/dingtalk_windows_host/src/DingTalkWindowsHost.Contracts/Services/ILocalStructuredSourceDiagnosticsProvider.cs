using DingTalkWindowsHost.Contracts.Models;

namespace DingTalkWindowsHost.Contracts.Services;

public interface ILocalStructuredSourceDiagnosticsProvider
{
    LocalStructuredSourceDiagnosticsResult GetDiagnostics(int candidateLimit);

    LocalStructuredSourceChangeDiagnosticsResult GetChangeDiagnostics(
        int candidateLimit,
        bool resetBaseline);

    LocalStructuredSourceInspectionDiagnosticsResult GetInspectionDiagnostics(
        int candidateLimit,
        int itemLimit);

    LocalStructuredContentShapeDiagnosticsResult GetContentShapeDiagnostics(
        int candidateLimit,
        int itemLimit,
        int sampleLimit);
}
