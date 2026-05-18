namespace DingTalkWindowsHost.Api;

public enum HostControlAction
{
    Start,
    Stop,
    Reload,
}

public sealed class HostControlState
{
    private volatile bool _captureRunning;

    public event EventHandler<HostControlAction>? ActionRequested;

    public bool CaptureRunning => _captureRunning;

    public void Start()
    {
        _captureRunning = true;
        ActionRequested?.Invoke(this, HostControlAction.Start);
    }

    public void Stop()
    {
        _captureRunning = false;
        ActionRequested?.Invoke(this, HostControlAction.Stop);
    }

    public void Reload()
    {
        _captureRunning = true;
        ActionRequested?.Invoke(this, HostControlAction.Reload);
    }
}
