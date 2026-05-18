using DingTalkWindowsHost.Contracts.Services;

namespace DingTalkWindowsHost.Automation.Capture;

public sealed class UiaSnapshotProvider : IUiaSnapshotProvider
{
    private readonly UiaChatSurfaceProbe _probe;

    public UiaSnapshotProvider(UiaChatSurfaceProbe probe)
    {
        ArgumentNullException.ThrowIfNull(probe);
        _probe = probe;
    }

    public IReadOnlyList<string> GetNodeSummary(IntPtr windowHandle, int limit)
    {
        return _probe.ProbeNodeSummary(windowHandle, limit);
    }

    public IReadOnlyList<string> GetMessageSurfaceNodeSummary(IntPtr windowHandle, int limit)
    {
        return _probe.ProbeMessageSurfaceNodeSummary(windowHandle, limit);
    }
}
