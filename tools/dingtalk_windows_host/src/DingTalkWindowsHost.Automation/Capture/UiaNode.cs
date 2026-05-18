namespace DingTalkWindowsHost.Automation.Capture;

public sealed record UiaNode(
    string AutomationId,
    string Name,
    string ControlType,
    string ClassName = "",
    string HelpText = "");
