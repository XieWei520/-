namespace DingTalkWindowsHost.Api;

public sealed record LoopbackStatusDto(
    bool CaptureRunning,
    DateTimeOffset ServerTime,
    string Version,
    string ShellState = "",
    string CurrentHwnd = "",
    string Message = "",
    DateTimeOffset? LastWindowEventAt = null,
    bool OcrEnabled = false,
    string ConversationReadiness = "NoConversationList",
    string ConversationReadinessMessage = "");
