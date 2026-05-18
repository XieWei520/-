using DingTalkWindowsHost.Automation.Capture;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class UiaChatSurfaceProbeTests
{
    [Fact]
    public void SummarizeNodes_limits_output_and_includes_node_identity()
    {
        var nodes = new[]
        {
            new UiaNode("messageBody", "hello", "Text", "TextBlock"),
            new UiaNode("senderName", "Alice", "Text", "Label"),
        };

        var summary = UiaChatSurfaceProbe.SummarizeNodes(nodes, maxNodes: 1);

        Assert.Single(summary);
        Assert.Contains("messageBody", summary[0], StringComparison.Ordinal);
        Assert.Contains("hello", summary[0], StringComparison.Ordinal);
    }

    [Fact]
    public void SummarizeNodes_can_include_help_text_for_message_surface_diagnostics()
    {
        var nodes = new[]
        {
            new UiaNode("widgetChatBubble", "hello", "Text", "DTIMChatBox", "pattern text"),
        };

        var summary = UiaChatSurfaceProbe.SummarizeNodes(
            nodes,
            maxNodes: 1,
            includeHelpText: true);

        var only = Assert.Single(summary);
        Assert.Contains("helpText='pattern text'", only, StringComparison.Ordinal);
    }

    [Fact]
    public void ReadNode_keeps_node_when_one_property_is_unavailable()
    {
        var node = UiaChatSurfaceProbe.ReadNode(
            automationId: static () => throw new InvalidOperationException("missing"),
            name: static () => "message text",
            controlType: static () => "Text",
            className: static () => "QLabel",
            helpText: static () => null);

        Assert.Equal(string.Empty, node.AutomationId);
        Assert.Equal("message text", node.Name);
        Assert.Equal("Text", node.ControlType);
        Assert.Equal("QLabel", node.ClassName);
    }
}
