namespace DingTalkWindowsHost.Automation.Capture;

public sealed class UiaMessageExtractor
{
    private static readonly string[] ConversationAutomationIds =
    {
        "sourceConversationName",
        "conversationName",
        "chatTitle",
        "groupName",
    };

    private static readonly string[] SenderAutomationIds =
    {
        "senderName",
        "messageSender",
        "fromName",
    };

    private static readonly string[] BodyAutomationIds =
    {
        "messageBody",
        "messageText",
        "textMessage",
    };

    private static readonly string[] NavigationNoiseAutomationIdPrefixes =
    {
        "navigator_view.",
        "ConvListView",
        "advancedSearch",
        "keep-focus-input",
    };

    private static readonly string[] NavigationNoiseTexts =
    {
        "\u6d88\u606f",
        "\u6587\u6863",
        "AI \u542c\u8bb0",
        "\u641c\u7d22\u6216\u63d0\u95ee",
    };

    public ExtractedMessage? ExtractLatest(IEnumerable<UiaNode> nodes)
    {
        ArgumentNullException.ThrowIfNull(nodes);

        var snapshot = nodes.ToArray();
        var sourceConversationName = FindFirstByAutomationId(snapshot, ConversationAutomationIds)
            ?? FindFirstLikelyConversationName(snapshot);
        var bodyIndex = FindLastForwardableBodyIndex(snapshot, FindMessageSurfaceStartIndex(snapshot));

        if (bodyIndex < 0)
        {
            return null;
        }

        var body = NormalizeText(snapshot[bodyIndex].Name);
        var senderName = FindNearestSender(snapshot, bodyIndex) ?? string.Empty;

        return new ExtractedMessage(
            SourceConversationName: sourceConversationName ?? string.Empty,
            SenderName: senderName,
            Text: body,
            ObservedAt: DateTimeOffset.UtcNow);
    }

    private static int FindLastForwardableBodyIndex(IReadOnlyList<UiaNode> nodes, int minimumIndex)
    {
        for (var index = nodes.Count - 1; index >= Math.Max(0, minimumIndex); index--)
        {
            var node = nodes[index];
            if (!IsPotentialBodyNode(node))
            {
                continue;
            }

            if (DingTalkMessageSurfaceDetector.IsComposerNode(node))
            {
                continue;
            }

            if (MatchesAny(node.AutomationId, ConversationAutomationIds)
                || MatchesAny(node.AutomationId, SenderAutomationIds))
            {
                continue;
            }

            var text = NormalizeText(node.Name);
            if (string.IsNullOrWhiteSpace(text) || IsLikelyNoise(text))
            {
                continue;
            }

            if (MatchesAny(node.AutomationId, BodyAutomationIds)
                || LooksLikeMessageBody(text)
                || IsNamedChatBubbleContentNode(node))
            {
                return index;
            }
        }

        return -1;
    }

    private static int FindMessageSurfaceStartIndex(IReadOnlyList<UiaNode> nodes)
    {
        for (var index = 0; index < nodes.Count; index++)
        {
            if (DingTalkMessageSurfaceDetector.IsChatBubbleNode(nodes[index]))
            {
                return index;
            }
        }

        for (var index = 0; index < nodes.Count; index++)
        {
            if (DingTalkMessageSurfaceDetector.IsMessageSurfaceNode(nodes[index]))
            {
                return index;
            }
        }

        return 0;
    }

    private static string? FindNearestSender(IReadOnlyList<UiaNode> nodes, int bodyIndex)
    {
        for (var index = bodyIndex - 1; index >= 0; index--)
        {
            var node = nodes[index];
            var text = NormalizeText(node.Name);

            if (string.IsNullOrWhiteSpace(text) || IsLikelyNoise(text) || IsLikelyNavigationNode(node))
            {
                continue;
            }

            if (MatchesAny(node.AutomationId, SenderAutomationIds))
            {
                return text;
            }

            if (IsTextLike(node) && text.Length <= 48 && !LooksLikeMessageBody(text))
            {
                return text;
            }
        }

        return null;
    }

    private static string? FindFirstByAutomationId(IEnumerable<UiaNode> nodes, IReadOnlyList<string> automationIds)
    {
        return nodes
            .Where(node => MatchesAny(node.AutomationId, automationIds))
            .Select(node => NormalizeText(node.Name))
            .FirstOrDefault(static text => !string.IsNullOrWhiteSpace(text));
    }

    private static string? FindFirstLikelyConversationName(IEnumerable<UiaNode> nodes)
    {
        return nodes
            .Where(IsTextLike)
            .Select(node => NormalizeText(node.Name))
            .FirstOrDefault(static text =>
                !string.IsNullOrWhiteSpace(text)
                && text.Length <= 80
                && !IsLikelyNoise(text));
    }

    private static bool MatchesAny(string value, IEnumerable<string> expectedValues)
    {
        return expectedValues.Any(expected => string.Equals(value, expected, StringComparison.OrdinalIgnoreCase));
    }

    private static bool IsPotentialBodyNode(UiaNode node)
    {
        return IsTextLike(node) || IsNamedChatBubbleContentNode(node);
    }

    private static bool IsTextLike(UiaNode node)
    {
        return string.Equals(node.ControlType, "Text", StringComparison.OrdinalIgnoreCase)
            || string.Equals(node.ControlType, "Edit", StringComparison.OrdinalIgnoreCase)
            || string.Equals(node.ControlType, "Document", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsNamedChatBubbleContentNode(UiaNode node)
    {
        if (string.IsNullOrWhiteSpace(node.Name)
            || !string.Equals(node.ControlType, "Group", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        return node.ClassName.Contains("ChatBubbleWidget", StringComparison.OrdinalIgnoreCase)
            || node.AutomationId.Contains("chatBubble", StringComparison.OrdinalIgnoreCase);
    }

    private static bool LooksLikeMessageBody(string text)
    {
        if (text.StartsWith("http://", StringComparison.OrdinalIgnoreCase)
            || text.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        return text.Length > 6
            || text.Contains(' ')
            || text.Contains('\u3002')
            || text.Contains('\uff0c')
            || text.Contains('!')
            || text.Contains('?')
            || text.Contains('\n')
            || text.Contains('\r')
            || text.Contains('[');
    }

    private static bool IsLikelyNoise(string text)
    {
        return text.Equals("DingTalk", StringComparison.OrdinalIgnoreCase)
            || text.Equals("\u9489\u9489", StringComparison.OrdinalIgnoreCase)
            || text.Contains("\u52a0\u8f7d\u4e2d", StringComparison.OrdinalIgnoreCase)
            || text.Contains("Loading", StringComparison.OrdinalIgnoreCase)
            || text.Contains("Enter/Alt+S", StringComparison.OrdinalIgnoreCase)
            || text.Contains("Ctrl+Enter", StringComparison.OrdinalIgnoreCase)
            || NavigationNoiseTexts.Any(noise => text.Equals(noise, StringComparison.OrdinalIgnoreCase))
            || IsClockText(text);
    }

    private static bool IsLikelyNavigationNode(UiaNode node)
    {
        return NavigationNoiseAutomationIdPrefixes.Any(prefix =>
            node.AutomationId.StartsWith(prefix, StringComparison.OrdinalIgnoreCase));
    }

    private static bool IsClockText(string text)
    {
        if (text.Length is < 4 or > 5)
        {
            return false;
        }

        var separatorIndex = text.IndexOf(':', StringComparison.Ordinal);
        return separatorIndex is 1 or 2
            && int.TryParse(text[..separatorIndex], out _)
            && int.TryParse(text[(separatorIndex + 1)..], out _);
    }

    private static string NormalizeText(string value)
    {
        return string.Join(' ', value.Split(Array.Empty<char>(), StringSplitOptions.RemoveEmptyEntries));
    }
}
