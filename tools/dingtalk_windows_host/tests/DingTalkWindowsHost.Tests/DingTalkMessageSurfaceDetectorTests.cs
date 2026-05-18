using DingTalkWindowsHost.Automation.Capture;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class DingTalkMessageSurfaceDetectorTests
{
    [Theory]
    [InlineData("qt_chat_navigable_content_widget.stackedWidget.mesasgePage", "", true)]
    [InlineData("qt_chat_navigable_content_widget.stackedWidget.messagePage", "", true)]
    [InlineData("qt_chat_navigable_content_widget.stackedWidget.mesasgePage.widget.splitter.widgetChatBubble", "", true)]
    [InlineData("", "DTIMContentModule", true)]
    [InlineData("ConvListView.widget.contentAreaStack.pageList.listView", "ConvListItemListView", false)]
    public void IsMessageSurfaceNode_detects_dingtalk_message_page_structure(
        string automationId,
        string className,
        bool expected)
    {
        var node = new UiaNode(
            AutomationId: automationId,
            Name: string.Empty,
            ControlType: "Pane",
            ClassName: className);

        Assert.Equal(expected, DingTalkMessageSurfaceDetector.IsMessageSurfaceNode(node));
    }

    [Theory]
    [InlineData("qt_chat_navigable_content_widget.stackedWidget.mesasgePage.widget.splitter.widgetChatBubble", "", true)]
    [InlineData("", "im_chat::DTIMChatBox", true)]
    [InlineData("qt_chat_navigable_content_widget.stackedWidget.mesasgePage.widget.splitter.widgetRichEditWnd", "", false)]
    public void IsChatBubbleNode_detects_message_bubble_container(
        string automationId,
        string className,
        bool expected)
    {
        var node = new UiaNode(
            AutomationId: automationId,
            Name: string.Empty,
            ControlType: "Pane",
            ClassName: className);

        Assert.Equal(expected, DingTalkMessageSurfaceDetector.IsChatBubbleNode(node));
    }

    [Theory]
    [InlineData("qt_chat_navigable_content_widget.stackedWidget.mesasgePage.widget.splitter.widgetRichEditWnd", true)]
    [InlineData("qt_chat_navigable_content_widget.stackedWidget.mesasgePage.widget.splitter.widgetRichEditWnd.drich_edit", true)]
    [InlineData("qt_chat_navigable_content_widget.stackedWidget.mesasgePage.widget.splitter.widgetChatBubble", false)]
    public void IsComposerNode_detects_message_input_editor(string automationId, bool expected)
    {
        var node = new UiaNode(
            AutomationId: automationId,
            Name: string.Empty,
            ControlType: "Pane",
            ClassName: string.Empty);

        Assert.Equal(expected, DingTalkMessageSurfaceDetector.IsComposerNode(node));
    }
}
