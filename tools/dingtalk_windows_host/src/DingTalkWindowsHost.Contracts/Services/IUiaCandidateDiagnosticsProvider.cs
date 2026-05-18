using DingTalkWindowsHost.Contracts.Models;

namespace DingTalkWindowsHost.Contracts.Services;

public interface IUiaCandidateDiagnosticsProvider
{
    UiaCandidateDiagnosticsResult ProbeCandidates(int candidateLimit, int snapshotLimit, int conversationLimit);
}
