namespace DingTalkWindowsHost.Automation.WindowHost;

internal static class DingTalkTransientOverlayClassifier
{
    private static readonly string[] ClassNameSignals =
    {
        "DTIMChatAtWndView",
        "DTIMChatAtRoleWndView",
        "DTIMChatAtListView",
        "AiAssistTrayMenuPanelView",
    };

    private static readonly string[] TitleSignals =
    {
        "AiAssistTrayMenuPanel",
    };

    public static bool IsTransientOverlay(WindowCandidate candidate)
    {
        return IsTransientOverlay(candidate.ClassName, candidate.Title);
    }

    public static bool IsTransientOverlay(string className, string title)
    {
        return ClassNameSignals.Any(signal =>
                className.Contains(signal, StringComparison.OrdinalIgnoreCase))
            || TitleSignals.Any(signal =>
                title.Contains(signal, StringComparison.OrdinalIgnoreCase));
    }
}
