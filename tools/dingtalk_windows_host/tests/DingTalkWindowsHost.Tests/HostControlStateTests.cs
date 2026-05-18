using DingTalkWindowsHost.Api;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class HostControlStateTests
{
    [Fact]
    public void Start_raises_requested_action()
    {
        var state = new HostControlState();
        var observed = new List<HostControlAction>();
        state.ActionRequested += (_, action) => observed.Add(action);

        state.Start();

        Assert.True(state.CaptureRunning);
        Assert.Equal(new[] { HostControlAction.Start }, observed);
    }

    [Fact]
    public void Reload_keeps_capture_running_and_raises_reload()
    {
        var state = new HostControlState();
        var observed = new List<HostControlAction>();
        state.ActionRequested += (_, action) => observed.Add(action);

        state.Reload();

        Assert.True(state.CaptureRunning);
        Assert.Equal(new[] { HostControlAction.Reload }, observed);
    }
}
