namespace DingTalkWindowsHost.Automation.WindowHost;

public interface IWindowEmbedder
{
    EmbeddedWindowState? CurrentState { get; }

    void Attach(IntPtr childHandle, IntPtr hostHandle, HostSurfaceBounds bounds);

    void Resize(HostSurfaceBounds bounds);

    void EnsureAttachment(IntPtr childHandle, IntPtr hostHandle, HostSurfaceBounds bounds);

    bool IsAttachedTo(IntPtr childHandle, IntPtr hostHandle);

    bool TryRestorePreviousAttachment();

    void Detach();
}
