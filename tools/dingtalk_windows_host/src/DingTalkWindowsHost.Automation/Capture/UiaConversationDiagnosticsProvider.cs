using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Contracts.Services;

namespace DingTalkWindowsHost.Automation.Capture;

public sealed class UiaConversationDiagnosticsProvider : IUiaConversationDiagnosticsProvider
{
    private readonly UiaChatSurfaceProbe _probe;

    public UiaConversationDiagnosticsProvider(UiaChatSurfaceProbe probe)
    {
        ArgumentNullException.ThrowIfNull(probe);
        _probe = probe;
    }

    public UiaConversationDiagnosticsResult GetDiagnostics(IntPtr windowHandle, int limit)
    {
        return _probe.ProbeConversationDiagnostics(windowHandle, limit);
    }
}
