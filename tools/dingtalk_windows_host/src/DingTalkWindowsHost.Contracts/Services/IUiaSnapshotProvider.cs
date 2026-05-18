namespace DingTalkWindowsHost.Contracts.Services;

public interface IUiaSnapshotProvider
{
    IReadOnlyList<string> GetNodeSummary(IntPtr windowHandle, int limit);

    IReadOnlyList<string> GetMessageSurfaceNodeSummary(IntPtr windowHandle, int limit);
}
