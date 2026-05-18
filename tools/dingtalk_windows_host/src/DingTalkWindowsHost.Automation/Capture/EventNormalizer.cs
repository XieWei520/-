using DingTalkWindowsHost.Contracts.Models;

namespace DingTalkWindowsHost.Automation.Capture;

public sealed class EventNormalizer
{
    public DingTalkObservedEvent? Normalize(ExtractedMessage message)
    {
        ArgumentNullException.ThrowIfNull(message);

        return DingTalkEventNormalizer.Normalize(
            message.SourceConversationName,
            message.SenderName,
            message.Text,
            message.ObservedAt,
            message.LocalImagePath,
            message.CaptureSource,
            message.SourceConversationIdHint);
    }
}
