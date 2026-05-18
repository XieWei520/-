using DingTalkWindowsHost.Automation.Capture;
using DingTalkWindowsHost.Contracts.Models;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class UiaConversationDiagnosticsTests
{
    [Fact]
    public void Extract_maps_conversation_list_items_from_conv_list_nodes()
    {
        var nodes = new[]
        {
            new UiaNode(
                AutomationId: "ConvListView.widget.contentAreaStack.pageList.listView",
                Name: string.Empty,
                ControlType: "List",
                ClassName: "ConvListItemListView"),
            new UiaNode(
                AutomationId: string.Empty,
                Name: "客户群A 2条未读",
                ControlType: "ListItem",
                ClassName: string.Empty),
            new UiaNode(
                AutomationId: string.Empty,
                Name: "项目群B",
                ControlType: "ListItem",
                ClassName: string.Empty),
        };

        var result = UiaConversationDiagnosticsExtractor.Extract(nodes, limit: 10);

        Assert.Equal(2, result.Conversations.Count);
        Assert.Equal("客户群A 2条未读", result.Conversations[0].Name);
        Assert.True(result.Conversations[0].HasUnreadHint);
        Assert.False(result.Conversations[1].HasUnreadHint);
    }

    [Fact]
    public void Extract_keeps_empty_conversation_list_items_as_stable_placeholders()
    {
        var nodes = new[]
        {
            new UiaNode(
                AutomationId: "ConvListView.widget.contentAreaStack.pageList.listView",
                Name: string.Empty,
                ControlType: "List",
                ClassName: "ConvListItemListView"),
            new UiaNode(
                AutomationId: string.Empty,
                Name: string.Empty,
                ControlType: "ListItem",
                ClassName: string.Empty),
            new UiaNode(
                AutomationId: string.Empty,
                Name: string.Empty,
                ControlType: "ListItem",
                ClassName: string.Empty),
        };

        var result = UiaConversationDiagnosticsExtractor.Extract(nodes, limit: 10);

        Assert.Equal(2, result.Conversations.Count);
        Assert.Equal("conversation-listitem-1", result.Conversations[0].AutomationId);
        Assert.Equal("(unnamed conversation #1)", result.Conversations[0].Name);
        Assert.Equal("conversation-listitem-2", result.Conversations[1].AutomationId);
        Assert.Equal("(unnamed conversation #2)", result.Conversations[1].Name);
        Assert.Equal(ConversationReadiness.ConversationListVisible, ConversationReadinessEvaluator.Evaluate(result));
        Assert.Contains("names are not exposed", result.Recommendation, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Extract_does_not_treat_navigation_scroll_items_as_conversations()
    {
        var nodes = new[]
        {
            new UiaNode(
                AutomationId: "dt_main_frame_view{default}.widget.splitter.widgetNevigationBarContainer.navigator_view.NavigatorAppItemContainer.im_im",
                Name: "\u6d88\u606f",
                ControlType: "Button",
                ClassName: "client_ding::NavigatorAppItemView"),
            new UiaNode(
                AutomationId: "dt_main_frame_view{default}.widget.splitter.widgetNevigationBarContainer.navigator_view.NavigatorScrollView",
                Name: string.Empty,
                ControlType: "List",
                ClassName: "client_ding::NavigatorScrollView"),
            new UiaNode(
                AutomationId: string.Empty,
                Name: string.Empty,
                ControlType: "ListItem",
                ClassName: string.Empty),
            new UiaNode(
                AutomationId: string.Empty,
                Name: string.Empty,
                ControlType: "ListItem",
                ClassName: string.Empty),
        };

        var result = UiaConversationDiagnosticsExtractor.Extract(nodes, limit: 10);

        Assert.Empty(result.Conversations);
        Assert.Equal(ConversationReadiness.NoConversationList, ConversationReadinessEvaluator.Evaluate(result));
    }

    [Fact]
    public void Extract_treats_visible_message_surface_as_ready_even_without_selected_listitem_hint()
    {
        var nodes = new[]
        {
            new UiaNode(
                AutomationId: "ConvListView.widget.contentAreaStack.pageList.listView",
                Name: string.Empty,
                ControlType: "List",
                ClassName: "ConvListItemListView"),
            new UiaNode(
                AutomationId: string.Empty,
                Name: string.Empty,
                ControlType: "ListItem",
                ClassName: string.Empty),
            new UiaNode(
                AutomationId: "qt_chat_navigable_content_widget.stackedWidget.mesasgePage",
                Name: string.Empty,
                ControlType: "Pane",
                ClassName: "DTIMContentModule"),
            new UiaNode(
                AutomationId: "qt_chat_navigable_content_widget.stackedWidget.mesasgePage.widget.splitter.widgetChatBubble",
                Name: string.Empty,
                ControlType: "Pane",
                ClassName: string.Empty),
        };

        var result = UiaConversationDiagnosticsExtractor.Extract(nodes, limit: 10);

        Assert.True(result.MessageSurfaceVisible);
        Assert.Equal(ConversationReadiness.Ready, ConversationReadinessEvaluator.Evaluate(result));
        Assert.Contains("message surface", result.Recommendation, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Extract_detects_restart_prompt_as_blocking_dialog()
    {
        var nodes = new[]
        {
            new UiaNode(
                AutomationId: string.Empty,
                Name: string.Empty,
                ControlType: "Window",
                ClassName: "MsgBox"),
            new UiaNode(
                AutomationId: string.Empty,
                Name: "为了确保您可以体验完整功能，请重启应用程序。是否立即重启？",
                ControlType: "Text",
                ClassName: string.Empty),
        };

        var result = UiaConversationDiagnosticsExtractor.Extract(nodes, limit: 10);

        var dialog = Assert.Single(result.BlockingDialogs);
        Assert.Equal("MsgBox", dialog.ClassName);
        Assert.Contains("重启", dialog.Message, StringComparison.Ordinal);
        Assert.Contains("Resolve blocking dialog", result.Recommendation, StringComparison.Ordinal);
    }

    [Fact]
    public void Extract_detects_dingtalk_safe_mode_prompt_as_blocking_dialog()
    {
        var nodes = new[]
        {
            new UiaNode(
                AutomationId: string.Empty,
                Name: "钉钉安全模式",
                ControlType: "Pane",
                ClassName: "#32770"),
            new UiaNode(
                AutomationId: "2",
                Name: "取消",
                ControlType: "Button",
                ClassName: "Button"),
            new UiaNode(
                AutomationId: "65535",
                Name: "当前检测出钉钉异常，请点击”确定“ 清理本地缓存尝试修复；",
                ControlType: "Text",
                ClassName: "Static"),
        };

        var result = UiaConversationDiagnosticsExtractor.Extract(nodes, limit: 10);

        var dialog = Assert.Single(result.BlockingDialogs);
        Assert.Equal("钉钉安全模式", dialog.Title);
        Assert.Equal("#32770", dialog.ClassName);
        Assert.Contains("清理本地缓存", dialog.Message, StringComparison.Ordinal);
        Assert.Contains("Resolve blocking dialog", result.Recommendation, StringComparison.Ordinal);
    }

    [Fact]
    public void Extract_reports_login_required_when_login_view_is_visible()
    {
        var nodes = new[]
        {
            new UiaNode(
                AutomationId: string.Empty,
                Name: "钉钉",
                ControlType: "Window",
                ClassName: "DtLoginView"),
            new UiaNode(
                AutomationId: "loginView.widgetContainer.loginAccountPageView.contentWidget.contentWidgetInner.labelWelcome",
                Name: "欢迎使用钉钉",
                ControlType: "Text",
                ClassName: "QLabel"),
            new UiaNode(
                AutomationId: "loginView.widgetContainer.loginAccountPageView.contentWidget.contentWidgetInner.btnLogin",
                Name: "登录",
                ControlType: "Button",
                ClassName: "QPushButton"),
        };

        var result = UiaConversationDiagnosticsExtractor.Extract(nodes, limit: 10);

        Assert.Empty(result.Conversations);
        Assert.Empty(result.BlockingDialogs);
        Assert.Contains("login-required", result.Recommendation, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("\u52A0\u5165\u56E2\u961F")]
    [InlineData("\u521B\u5EFA\u56E2\u961F")]
    [InlineData("\u9009\u62E9\u56E2\u961F")]
    public void Extract_reports_login_required_when_team_setup_view_is_visible(string setupActionName)
    {
        var nodes = new[]
        {
            new UiaNode(
                AutomationId: "dt_main_frame_view{default}",
                Name: "\u9489\u9489",
                ControlType: "Window",
                ClassName: "DtMainFrameView"),
            new UiaNode(
                AutomationId: "teamSetupAction",
                Name: setupActionName,
                ControlType: "Button",
                ClassName: "QPushButton"),
        };

        var result = UiaConversationDiagnosticsExtractor.Extract(nodes, limit: 10);

        Assert.Empty(result.Conversations);
        Assert.Empty(result.BlockingDialogs);
        Assert.Contains("login-required", result.Recommendation, StringComparison.Ordinal);
        Assert.Equal(ConversationReadiness.LoginRequired, ConversationReadinessEvaluator.Evaluate(result));
    }

    [Theory]
    [InlineData("advancedSearch", "", "", "")]
    [InlineData("keep-focus-input", "", "", "")]
    [InlineData("", "搜索或提问", "", "")]
    [InlineData("", "", "", "UIMaskWnd")]
    public void Extract_reports_blocked_by_overlay_when_search_or_mask_overlay_is_visible(
        string automationId,
        string name,
        string controlType,
        string className)
    {
        var nodes = new[]
        {
            new UiaNode(
                AutomationId: automationId,
                Name: name,
                ControlType: controlType,
                ClassName: className),
        };

        var result = UiaConversationDiagnosticsExtractor.Extract(nodes, limit: 10);

        Assert.Empty(result.Conversations);
        Assert.Empty(result.BlockingDialogs);
        Assert.Contains("blocked-by-overlay", result.Recommendation, StringComparison.Ordinal);
        Assert.Equal(ConversationReadiness.BlockedByOverlay, ConversationReadinessEvaluator.Evaluate(result));
    }

    [Fact]
    public void Extract_limits_conversation_count()
    {
        var nodes = new[]
        {
            new UiaNode("list", string.Empty, "List", "ConvListItemListView"),
            new UiaNode("a", "A", "ListItem", string.Empty),
            new UiaNode("b", "B", "ListItem", string.Empty),
            new UiaNode("c", "C", "ListItem", string.Empty),
        };

        var result = UiaConversationDiagnosticsExtractor.Extract(nodes, limit: 2);

        Assert.Equal(2, result.Conversations.Count);
    }
}
