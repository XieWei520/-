using DingTalkWindowsHost.Contracts.Models;

namespace DingTalkWindowsHost.Automation.Capture;

public sealed record ExtractedMessage(
    string SourceConversationName,
    string SenderName,
    string Text,
    DateTimeOffset ObservedAt,
    string LocalImagePath = "",
    CaptureSource CaptureSource = CaptureSource.UiaText,
    string SourceConversationIdHint = "");
