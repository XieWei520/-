using DingTalkWindowsHost.Contracts.Models;

namespace DingTalkWindowsHost.Contracts.Services;

public interface IClipboardMessageProbe
{
    ExtractedClipboardMessage? ProbeLatest(IntPtr windowHandle);

    ClipboardMessageProbeDiagnosticsResult GetDiagnostics(IntPtr windowHandle);
}

public sealed record ExtractedClipboardMessage(
    string SourceConversationName,
    string SenderName,
    string Text,
    DateTimeOffset ObservedAt,
    string SourceConversationIdHint);
