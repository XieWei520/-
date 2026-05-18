namespace DingTalkWindowsHost.Automation.StructuredSources;

public sealed record DevToolsVersionMetadata(
    int Port,
    string Browser,
    string ProtocolVersion,
    bool HasWebSocketDebuggerUrl);
