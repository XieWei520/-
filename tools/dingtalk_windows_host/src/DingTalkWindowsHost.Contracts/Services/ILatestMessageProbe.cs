using DingTalkWindowsHost.Contracts.Models;

namespace DingTalkWindowsHost.Contracts.Services;

public interface ILatestMessageProbe
{
    LatestProbeMessage? ProbeLatest();
}

public sealed record LatestProbeMessage(
    string SourceConversationName,
    string SenderName,
    string Text,
    DateTimeOffset ObservedAt,
    string LocalImagePath = "",
    CaptureSource CaptureSource = CaptureSource.UiaText,
    string SourceConversationIdHint = "");
