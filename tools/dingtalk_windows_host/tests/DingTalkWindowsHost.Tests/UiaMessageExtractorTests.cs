using DingTalkWindowsHost.Automation.Capture;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class UiaMessageExtractorTests
{
    [Fact]
    public void ExtractLatest_accepts_short_text_from_named_chat_bubble_content()
    {
        var extractor = new UiaMessageExtractor();
        var nodes = new[]
        {
            new UiaNode(
                AutomationId: "messageList",
                Name: string.Empty,
                ControlType: "Group",
                ClassName: "MessageListWidget"),
            new UiaNode(
                AutomationId: "senderName",
                Name: "Alice",
                ControlType: "Text"),
            new UiaNode(
                AutomationId: "chatBubbleContent",
                Name: "收到",
                ControlType: "Group",
                ClassName: "ChatBubbleWidget"),
        };

        var result = extractor.ExtractLatest(nodes);

        Assert.NotNull(result);
        Assert.Equal("收到", result!.Text);
        Assert.Equal("Alice", result.SenderName);
    }

    [Fact]
    public void ExtractLatest_rejects_short_text_from_generic_group()
    {
        var extractor = new UiaMessageExtractor();
        var nodes = new[]
        {
            new UiaNode(
                AutomationId: "messageList",
                Name: string.Empty,
                ControlType: "Group",
                ClassName: "MessageListWidget"),
            new UiaNode(
                AutomationId: "genericStatus",
                Name: "收到",
                ControlType: "Group",
                ClassName: "GenericWidget"),
        };

        var result = extractor.ExtractLatest(nodes);

        Assert.Null(result);
    }
}
