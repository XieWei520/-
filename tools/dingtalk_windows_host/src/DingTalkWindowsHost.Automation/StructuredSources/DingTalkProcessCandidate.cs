namespace DingTalkWindowsHost.Automation.StructuredSources;

public sealed record DingTalkProcessCandidate(
    int ProcessId,
    string ProcessName,
    IntPtr MainWindowHandle,
    string MainWindowTitle,
    string CommandLine = "");
