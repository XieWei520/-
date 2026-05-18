using DingTalkWindowsHost.Contracts.Services;

namespace DingTalkWindowsHost.Automation.Capture;

public sealed class LatestMessageProbeAdapter : ILatestMessageProbe
{
    private readonly UiaMessageProbeCoordinator _coordinator;

    public LatestMessageProbeAdapter(UiaMessageProbeCoordinator coordinator)
    {
        ArgumentNullException.ThrowIfNull(coordinator);
        _coordinator = coordinator;
    }

    public LatestProbeMessage? ProbeLatest()
    {
        var message = _coordinator.ProbeLatest();
        return message is null
            ? null
            : new LatestProbeMessage(
                SourceConversationName: message.SourceConversationName,
                SenderName: message.SenderName,
                Text: message.Text,
                ObservedAt: message.ObservedAt,
                LocalImagePath: message.LocalImagePath,
                CaptureSource: message.CaptureSource,
                SourceConversationIdHint: message.SourceConversationIdHint);
    }
}
