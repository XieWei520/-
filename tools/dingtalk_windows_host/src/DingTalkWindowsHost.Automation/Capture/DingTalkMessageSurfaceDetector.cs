namespace DingTalkWindowsHost.Automation.Capture;

internal static class DingTalkMessageSurfaceDetector
{
    public static bool IsMessageSurfaceNode(UiaNode node)
    {
        return node.AutomationId.Contains("mesasgePage", StringComparison.OrdinalIgnoreCase)
            || node.AutomationId.Contains("messagePage", StringComparison.OrdinalIgnoreCase)
            || node.AutomationId.Contains("widgetChatBubble", StringComparison.OrdinalIgnoreCase)
            || string.Equals(node.ClassName, "DTIMContentModule", StringComparison.OrdinalIgnoreCase);
    }

    public static bool IsChatBubbleNode(UiaNode node)
    {
        return node.AutomationId.Contains("widgetChatBubble", StringComparison.OrdinalIgnoreCase)
            || node.ClassName.Contains("DTIMChatBox", StringComparison.OrdinalIgnoreCase);
    }

    public static bool IsComposerNode(UiaNode node)
    {
        return node.AutomationId.Contains("widgetRichEditWnd", StringComparison.OrdinalIgnoreCase)
            || node.AutomationId.Contains("drich_edit", StringComparison.OrdinalIgnoreCase);
    }
}
