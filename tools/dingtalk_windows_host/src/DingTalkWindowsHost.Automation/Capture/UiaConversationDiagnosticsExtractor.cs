using DingTalkWindowsHost.Contracts.Models;

namespace DingTalkWindowsHost.Automation.Capture;

public static class UiaConversationDiagnosticsExtractor
{
    private static readonly string[] BlockingDialogClassNames =
    {
        "MsgBox",
        "OperationTaskDlg",
    };

    public static UiaConversationDiagnosticsResult Extract(IEnumerable<UiaNode> nodes, int limit)
    {
        ArgumentNullException.ThrowIfNull(nodes);

        var snapshot = nodes.ToArray();
        var conversations = ExtractConversations(snapshot, Math.Max(0, limit));
        var dialogs = ExtractBlockingDialogs(snapshot);
        var messageSurfaceVisible = HasMessageSurface(snapshot);
        return new UiaConversationDiagnosticsResult(
            ObservedAt: DateTimeOffset.UtcNow,
            Conversations: conversations,
            BlockingDialogs: dialogs,
            Recommendation: BuildRecommendation(snapshot, conversations, dialogs, messageSurfaceVisible),
            MessageSurfaceVisible: messageSurfaceVisible);
    }

    private static IReadOnlyList<UiaConversationItem> ExtractConversations(
        IReadOnlyList<UiaNode> nodes,
        int limit)
    {
        var hasConversationList = nodes.Any(IsConversationListContainer);
        if (!hasConversationList)
        {
            return Array.Empty<UiaConversationItem>();
        }

        return nodes
            .Where(IsConversationListItem)
            .Take(limit)
            .Select(static (node, index) => new UiaConversationItem(
                AutomationId: BuildConversationAutomationId(node, index),
                Name: BuildConversationName(node, index),
                IsSelected: IsSelectedHint(node),
                HasUnreadHint: HasUnreadHint(node)))
            .ToArray();
    }

    private static IReadOnlyList<UiaBlockingDialog> ExtractBlockingDialogs(IReadOnlyList<UiaNode> nodes)
    {
        var dialogs = new List<UiaBlockingDialog>();
        for (var index = 0; index < nodes.Count; index++)
        {
            var node = nodes[index];
            if (!IsBlockingDialogNode(node))
            {
                continue;
            }

            var message = nodes
                .Skip(index + 1)
                .Take(8)
                .FirstOrDefault(static candidate =>
                    string.Equals(candidate.ControlType, "Text", StringComparison.OrdinalIgnoreCase)
                    && !string.IsNullOrWhiteSpace(candidate.Name))
                ?.Name ?? string.Empty;

            dialogs.Add(new UiaBlockingDialog(
                Title: node.Name,
                Message: message,
                ClassName: node.ClassName));
        }

        return dialogs;
    }

    private static string BuildRecommendation(
        IReadOnlyList<UiaNode> nodes,
        IReadOnlyList<UiaConversationItem> conversations,
        IReadOnlyList<UiaBlockingDialog> dialogs,
        bool messageSurfaceVisible)
    {
        if (dialogs.Count > 0)
        {
            return "Resolve blocking dialog before capture.";
        }

        if (nodes.Any(IsLoginNode))
        {
            return "login-required: DingTalk is showing the login view; sign in before capture.";
        }

        if (nodes.Any(IsBlockingOverlayNode))
        {
            return "blocked-by-overlay: DingTalk search or mask overlay is covering the conversation surface.";
        }

        if (conversations.Count > 0)
        {
            if (messageSurfaceVisible)
            {
                return "Conversation list and message surface are visible; treat the active chat as selected even when UIA does not expose ListItem selection.";
            }

            if (conversations.All(static conversation => IsPlaceholderConversationName(conversation.Name)))
            {
                return "Conversation list items are visible, but names are not exposed through UIA; use structural changes as low-latency triggers while probing message content.";
            }

            return "Use conversation list changes as low-latency triggers; message body still needs another source.";
        }

        return "Conversation list was not exposed through UIA for this window.";
    }

    private static bool IsConversationListContainer(UiaNode node)
    {
        return node.AutomationId.Contains("ConvListView", StringComparison.OrdinalIgnoreCase)
            || string.Equals(node.ClassName, "ConvListItemListView", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsConversationListItem(UiaNode node)
    {
        return string.Equals(node.ControlType, "ListItem", StringComparison.OrdinalIgnoreCase);
    }

    private static bool HasMessageSurface(IReadOnlyList<UiaNode> nodes)
    {
        return nodes.Any(DingTalkMessageSurfaceDetector.IsMessageSurfaceNode);
    }

    private static string BuildConversationAutomationId(UiaNode node, int zeroBasedIndex)
    {
        return string.IsNullOrWhiteSpace(node.AutomationId)
            ? "conversation-listitem-" + (zeroBasedIndex + 1).ToString(System.Globalization.CultureInfo.InvariantCulture)
            : node.AutomationId;
    }

    private static string BuildConversationName(UiaNode node, int zeroBasedIndex)
    {
        return string.IsNullOrWhiteSpace(node.Name)
            ? "(unnamed conversation #" + (zeroBasedIndex + 1).ToString(System.Globalization.CultureInfo.InvariantCulture) + ")"
            : node.Name;
    }

    private static bool IsPlaceholderConversationName(string name)
    {
        return name.StartsWith("(unnamed conversation #", StringComparison.Ordinal);
    }

    private static bool IsBlockingDialogNode(UiaNode node)
    {
        if (string.Equals(node.ControlType, "Window", StringComparison.OrdinalIgnoreCase)
            && BlockingDialogClassNames.Any(className =>
                string.Equals(node.ClassName, className, StringComparison.OrdinalIgnoreCase)))
        {
            return true;
        }

        return IsDingTalkSafeModeDialog(node);
    }

    private static bool IsDingTalkSafeModeDialog(UiaNode node)
    {
        return string.Equals(node.ClassName, "#32770", StringComparison.OrdinalIgnoreCase)
            && (node.Name.Contains("钉钉安全模式", StringComparison.OrdinalIgnoreCase)
                || node.Name.Contains("钉钉异常", StringComparison.OrdinalIgnoreCase)
                || node.Name.Contains("清理本地缓存", StringComparison.OrdinalIgnoreCase));
    }

    private static bool IsLoginNode(UiaNode node)
    {
        return node.AutomationId.Contains("loginView", StringComparison.OrdinalIgnoreCase)
            || node.ClassName.Contains("DtLogin", StringComparison.OrdinalIgnoreCase)
            || node.Name.Contains("\u52A0\u5165\u56E2\u961F", StringComparison.OrdinalIgnoreCase)
            || node.Name.Contains("\u521B\u5EFA\u56E2\u961F", StringComparison.OrdinalIgnoreCase)
            || node.Name.Contains("\u9009\u62E9\u56E2\u961F", StringComparison.OrdinalIgnoreCase)
            || node.Name.Contains("欢迎使用钉钉", StringComparison.OrdinalIgnoreCase)
            || (node.Name.Equals("登录", StringComparison.OrdinalIgnoreCase)
                && string.Equals(node.ControlType, "Button", StringComparison.OrdinalIgnoreCase));
    }

    private static bool IsBlockingOverlayNode(UiaNode node)
    {
        return node.AutomationId.Contains("advancedSearch", StringComparison.OrdinalIgnoreCase)
            || node.AutomationId.Contains("keep-focus-input", StringComparison.OrdinalIgnoreCase)
            || string.Equals(node.ClassName, "UIMaskWnd", StringComparison.OrdinalIgnoreCase)
            || string.Equals(node.ClassName, "MaskWindow", StringComparison.OrdinalIgnoreCase)
            || string.Equals(node.Name, "搜索或提问", StringComparison.OrdinalIgnoreCase);
    }

    private static bool HasUnreadHint(UiaNode node)
    {
        return node.Name.Contains("未读", StringComparison.OrdinalIgnoreCase)
            || node.Name.Contains("条", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsSelectedHint(UiaNode node)
    {
        return node.AutomationId.Contains("selected", StringComparison.OrdinalIgnoreCase)
            || node.HelpText.Contains("selected", StringComparison.OrdinalIgnoreCase)
            || node.HelpText.Contains("选中", StringComparison.OrdinalIgnoreCase);
    }
}
