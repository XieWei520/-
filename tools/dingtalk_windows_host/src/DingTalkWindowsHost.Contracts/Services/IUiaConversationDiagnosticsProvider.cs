using DingTalkWindowsHost.Contracts.Models;

namespace DingTalkWindowsHost.Contracts.Services;

public interface IUiaConversationDiagnosticsProvider
{
    UiaConversationDiagnosticsResult GetDiagnostics(IntPtr windowHandle, int limit);
}
