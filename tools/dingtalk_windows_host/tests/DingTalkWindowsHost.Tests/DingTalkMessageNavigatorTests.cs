using DingTalkWindowsHost.Automation.Capture;
using DingTalkWindowsHost.Automation.WindowHost;
using DingTalkWindowsHost.Contracts.Models;
using System.Drawing;
using System.Runtime.InteropServices;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class DingTalkMessageNavigatorTests
{
    [Theory]
    [InlineData("advancedSearch", "", "", true)]
    [InlineData("keep-focus-input", "", "", true)]
    [InlineData("", "搜索或提问", "", true)]
    [InlineData("DTIMChatAtWndView", "Form", "DTIMChatAtWndView", true)]
    [InlineData("DTIMChatAtWndView.chat_at_list", "群成员", "DTIMChatAtListView", true)]
    [InlineData("DTIMChatAtRoleWndView", "Form", "DTIMChatAtRoleWndView", true)]
    [InlineData("AiAssistTrayMenuPanel", "Form", "client_ding::AiAssistTrayMenuPanelView", true)]
    [InlineData("navigator_view.im_im", "消息", "Button", false)]
    public void IsSearchOverlayNode_detects_advanced_search_signals(
        string automationId,
        string name,
        string className,
        bool expected)
    {
        var node = new UiaNode(
            AutomationId: automationId,
            Name: name,
            ControlType: string.Empty,
            ClassName: className);

        Assert.Equal(expected, DingTalkMessageNavigator.IsSearchOverlayNode(node));
    }

    [Theory]
    [InlineData("close-search-button", "", "", true)]
    [InlineData("", "\u8fd4\u56de", "Image", true)]
    [InlineData("", "\u5173\u95ed", "Button", true)]
    [InlineData("keep-focus-input", "\u641c\u7d22\u6216\u63d0\u95ee", "Edit", false)]
    [InlineData("navigator_view.im_im", "\u6d88\u606f", "Button", false)]
    public void IsSearchOverlayDismissNode_detects_close_controls(
        string automationId,
        string name,
        string controlType,
        bool expected)
    {
        var node = new UiaNode(
            AutomationId: automationId,
            Name: name,
            ControlType: controlType,
            ClassName: string.Empty);

        Assert.Equal(expected, DingTalkMessageNavigator.IsSearchOverlayDismissNode(node));
    }

    [Theory]
    [InlineData(false, false, DingTalkWindowsHost.Contracts.Models.DingTalkNavigationStatus.NotPresent)]
    [InlineData(false, true, DingTalkWindowsHost.Contracts.Models.DingTalkNavigationStatus.NotPresent)]
    [InlineData(true, true, DingTalkWindowsHost.Contracts.Models.DingTalkNavigationStatus.Failed)]
    [InlineData(true, false, DingTalkWindowsHost.Contracts.Models.DingTalkNavigationStatus.Closed)]
    public void ResolveCloseSearchOverlayStatus_reports_failed_when_overlay_remains(
        bool closeAttempted,
        bool stillPresent,
        DingTalkWindowsHost.Contracts.Models.DingTalkNavigationStatus expected)
    {
        Assert.Equal(
            expected,
            DingTalkMessageNavigator.ResolveCloseSearchOverlayStatus(closeAttempted, stillPresent));
    }

    [Theory]
    [InlineData(true, "Chrome_RenderWidgetHostHWND", true)]
    [InlineData(true, "Chrome_WidgetWin_1", true)]
    [InlineData(true, "CefBrowserWindow", true)]
    [InlineData(false, "Chrome_RenderWidgetHostHWND", false)]
    [InlineData(false, "Chrome_WidgetWin_1", false)]
    [InlineData(false, "CefBrowserWindow", false)]
    [InlineData(true, "Qt51511QWindowIcon", false)]
    [InlineData(true, "DTIMChatAtWndView", true)]
    [InlineData(true, "DTIMChatAtRoleWndView", true)]
    public void IsSearchOverlayProbeCandidate_only_accepts_visible_content_windows(
        bool isVisible,
        string className,
        bool expected)
    {
        var candidate = new WindowCandidate(
            Handle: new IntPtr(123),
            Title: string.Empty,
            ClassName: className,
            IsVisible: isVisible,
            IsEnabled: true,
            IsTopLevel: false,
            IsToolWindow: false,
            Width: 800,
            Height: 600,
            ZOrder: 0,
            ProcessName: "DingTalk");

        Assert.Equal(expected, DingTalkMessageNavigator.IsSearchOverlayProbeCandidate(candidate));
    }

    [Fact]
    public void IsSearchOverlayProbeCandidate_accepts_visible_top_level_qt_shell_for_overlay_probe()
    {
        var candidate = new WindowCandidate(
            Handle: new IntPtr(123),
            Title: "DingTalk",
            ClassName: "Qt51511QWindowIcon",
            IsVisible: true,
            IsEnabled: true,
            IsTopLevel: true,
            IsToolWindow: false,
            Width: 818,
            Height: 647,
            ZOrder: 0,
            ProcessName: "DingTalk");

        Assert.True(DingTalkMessageNavigator.IsSearchOverlayProbeCandidate(candidate));
    }

    [Theory]
    [InlineData("navigator_view.im_im", "", "Group", true)]
    [InlineData("root.left.NavigatorAppItemContainer.im_im", "\u6d88\u606f", "Button", true)]
    [InlineData("", "\u6d88\u606f", "Button", true)]
    [InlineData("root.left.NavigatorAppItemContainer.doc_doc", "\u6587\u6863", "Button", false)]
    [InlineData("navigator_view.contact_contact", "\u901a\u8baf\u5f55", "Button", false)]
    [InlineData("", "\u6d88\u606f", "Text", false)]
    public void IsMessageNavigatorNode_detects_messages_navigation_item(
        string automationId,
        string name,
        string controlType,
        bool expected)
    {
        var node = new UiaNode(
            AutomationId: automationId,
            Name: name,
            ControlType: controlType,
            ClassName: string.Empty);

        Assert.Equal(expected, DingTalkMessageNavigator.IsMessageNavigatorNode(node));
    }

    [Theory]
    [InlineData(ConversationReadiness.ConversationListVisible, true)]
    [InlineData(ConversationReadiness.Ready, false)]
    [InlineData(ConversationReadiness.NoConversationList, false)]
    public void ShouldSelectFirstConversation_only_when_conversation_list_is_visible(
        ConversationReadiness readiness,
        bool expected)
    {
        var diagnostics = new UiaConversationDiagnosticsResult(
            ObservedAt: DateTimeOffset.UtcNow,
            Conversations: readiness == ConversationReadiness.NoConversationList
                ? Array.Empty<UiaConversationItem>()
                : new[]
                {
                    new UiaConversationItem(
                        AutomationId: "conversation-listitem-1",
                        Name: "(unnamed conversation #1)",
                        IsSelected: readiness == ConversationReadiness.Ready,
                        HasUnreadHint: false),
                },
            BlockingDialogs: Array.Empty<UiaBlockingDialog>(),
            Recommendation: readiness == ConversationReadiness.Ready
                ? "Conversation list is visible and a selected conversation is present."
                : readiness == ConversationReadiness.ConversationListVisible
                    ? "Conversation list items are visible, but names are not exposed through UIA."
                    : "Conversation list is not visible through UIA.");

        Assert.Equal(expected, DingTalkMessageNavigator.ShouldSelectFirstConversation(diagnostics));
    }

    [Theory]
    [InlineData(true, false, DingTalkNavigationStatus.TargetNotFound)]
    [InlineData(false, true, DingTalkNavigationStatus.Activated)]
    [InlineData(false, false, DingTalkNavigationStatus.TargetNotFound)]
    public void ResolveOpenMessagesStatus_treats_visible_conversation_list_as_success(
        bool navigatorActivated,
        bool conversationListVisible,
        DingTalkNavigationStatus expected)
    {
        Assert.Equal(
            expected,
            DingTalkMessageNavigator.ResolveOpenMessagesStatus(navigatorActivated, conversationListVisible));
    }

    [Fact]
    public void ResolveRecoverableOpenMessagesStatus_does_not_report_failed_for_transient_uia_loss()
    {
        Assert.Equal(
            DingTalkNavigationStatus.TargetNotFound,
            DingTalkMessageNavigator.ResolveRecoverableOpenMessagesStatus(
                navigatorActivated: false,
                conversationListVisible: false));
    }

    [Theory]
    [InlineData(true, false, false, true)]
    [InlineData(true, true, false, false)]
    [InlineData(false, false, false, false)]
    [InlineData(true, false, true, false)]
    public void ShouldTryNavigatorFallbackAfterActivation_only_when_invoke_did_not_reveal_list(
        bool navigatorActivated,
        bool conversationListVisible,
        bool fallbackAlreadyAttempted,
        bool expected)
    {
        Assert.Equal(
            expected,
            DingTalkMessageNavigator.ShouldTryNavigatorFallbackAfterActivation(
                navigatorActivated,
                conversationListVisible,
                fallbackAlreadyAttempted));
    }

    [Fact]
    public void BuildOpenMessagesMessage_reports_degraded_success_when_uia_step_failed_after_list_visible()
    {
        var message = DingTalkMessageNavigator.BuildOpenMessagesMessage(
            navigatorActivated: false,
            selectedFirstConversation: false,
            conversationListVisible: true,
            recoverableFailure: "UIA Timeout");

        Assert.Contains("already visible", message, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("degraded", message, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("UIA Timeout", message, StringComparison.Ordinal);
    }

    [Fact]
    public void BuildOpenMessagesMessage_reports_unconfirmed_first_conversation_selection()
    {
        var message = DingTalkMessageNavigator.BuildOpenMessagesMessage(
            navigatorActivated: true,
            selectedFirstConversation: false,
            conversationListVisible: true,
            recoverableFailure: string.Empty);

        Assert.Contains("selection was not confirmed", message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void BuildOpenMessagesMessage_reports_unconfirmed_conversation_list_after_click()
    {
        var message = DingTalkMessageNavigator.BuildOpenMessagesMessage(
            navigatorActivated: true,
            selectedFirstConversation: false,
            conversationListVisible: false,
            recoverableFailure: string.Empty);

        Assert.Contains("navigator button was activated", message, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("conversation list was not confirmed", message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void BuildOpenMessagesMessage_reports_confirmed_active_surface_when_already_ready()
    {
        var message = DingTalkMessageNavigator.BuildOpenMessagesMessage(
            navigatorActivated: false,
            selectedFirstConversation: true,
            conversationListVisible: true,
            recoverableFailure: string.Empty);

        Assert.Contains("already visible", message, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("active conversation surface", message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void BuildOpenMessagesMessage_includes_exception_type_when_recoverable_message_is_empty()
    {
        var recoverableFailure = DingTalkMessageNavigator.FormatRecoverableNavigationFailure(
            new ExternalException());

        var message = DingTalkMessageNavigator.BuildOpenMessagesMessage(
            navigatorActivated: true,
            selectedFirstConversation: false,
            conversationListVisible: false,
            recoverableFailure: recoverableFailure);

        Assert.Contains("ExternalException", message, StringComparison.Ordinal);
        Assert.Contains("HResult=", message, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData(ConversationReadiness.Ready, true)]
    [InlineData(ConversationReadiness.ConversationListVisible, false)]
    [InlineData(ConversationReadiness.NoConversationList, false)]
    public void IsConversationSelectionConfirmed_requires_ready_diagnostics(
        ConversationReadiness readiness,
        bool expected)
    {
        var diagnostics = new UiaConversationDiagnosticsResult(
            ObservedAt: DateTimeOffset.UtcNow,
            Conversations: readiness == ConversationReadiness.NoConversationList
                ? Array.Empty<UiaConversationItem>()
                : new[]
                {
                    new UiaConversationItem(
                        AutomationId: "conversation-listitem-1",
                        Name: "(unnamed conversation #1)",
                        IsSelected: readiness == ConversationReadiness.Ready,
                        HasUnreadHint: false),
                },
            BlockingDialogs: Array.Empty<UiaBlockingDialog>(),
            Recommendation: readiness == ConversationReadiness.NoConversationList
                ? "Conversation list is not visible through UIA."
                : "Conversation list items are visible.");

        Assert.Equal(expected, DingTalkMessageNavigator.IsConversationSelectionConfirmed(diagnostics));
    }

    [Fact]
    public void IsConversationSelectionConfirmed_accepts_message_surface_ready_signal()
    {
        var diagnostics = new UiaConversationDiagnosticsResult(
            ObservedAt: DateTimeOffset.UtcNow,
            Conversations: new[]
            {
                new UiaConversationItem(
                    AutomationId: "conversation-listitem-1",
                    Name: "(unnamed conversation #1)",
                    IsSelected: false,
                    HasUnreadHint: false),
            },
            BlockingDialogs: Array.Empty<UiaBlockingDialog>(),
            Recommendation: "Conversation list and message surface are visible.",
            MessageSurfaceVisible: true);

        Assert.True(DingTalkMessageNavigator.IsConversationSelectionConfirmed(diagnostics));
    }

    [Theory]
    [InlineData("ConvListView.widget.contentAreaStack.pageList.listView", "ConvListItemListView", true)]
    [InlineData("", "ConvListItemListView", true)]
    [InlineData("ConvListView.widget.contentAreaStack.pageList.listView", "List", true)]
    [InlineData("other", "OtherList", false)]
    public void IsConversationListContainerNode_detects_conv_list_nodes(
        string automationId,
        string className,
        bool expected)
    {
        var node = new UiaNode(
            AutomationId: automationId,
            Name: string.Empty,
            ControlType: "List",
            ClassName: className);

        Assert.Equal(expected, DingTalkMessageNavigator.IsConversationListContainerNode(node));
    }

    [Fact]
    public void ResolveNavigationWindowHandle_prefers_main_window_candidate_over_hosted_child()
    {
        var navigator = new DingTalkMessageNavigator(new DingTalkWindowLocator(static () => new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x920C50),
                Title: string.Empty,
                ClassName: "DTIMChatAtWndView",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: false,
                Width: 0,
                Height: 0,
                ZOrder: 0,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x970C4E),
                Title: "DingTalk",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: false,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 818,
                Height: 647,
                ZOrder: 1,
                ProcessName: "DingTalk"),
        }));

        var resolved = navigator.ResolveNavigationWindowHandle(new IntPtr(0x920C50));

        Assert.Equal(new IntPtr(0x970C4E), resolved);
    }

    [Fact]
    public void ResolveNavigationWindowHandle_keeps_current_hosted_main_frame_over_hidden_overlay_candidate()
    {
        var navigator = new DingTalkMessageNavigator(new DingTalkWindowLocator(static () => new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x2790B8A),
                Title: "\u9489\u9489",
                ClassName: "StandardFrame_DingTalk",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: false,
                Width: 896,
                Height: 612,
                ZOrder: 0,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0xE0D04),
                Title: "DingTalk",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: false,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 818,
                Height: 647,
                ZOrder: 1,
                ProcessName: "DingTalk"),
        }));

        var resolved = navigator.ResolveNavigationWindowHandle(new IntPtr(0x2790B8A));

        Assert.Equal(new IntPtr(0x2790B8A), resolved);
    }

    [Theory]
    [InlineData(100, 200, 260, 72, 204, 236, true)]
    [InlineData(100, 200, 60, 72, 152, 236, true)]
    [InlineData(100, 200, 0, 72, 0, 0, false)]
    [InlineData(100, 200, 260, 0, 0, 0, false)]
    public void TryBuildConversationClickPoint_prefers_conversation_content_area(
        int left,
        int top,
        int width,
        int height,
        int expectedX,
        int expectedY,
        bool expected)
    {
        var result = DingTalkMessageNavigator.TryBuildConversationClickPoint(
            new Rectangle(left, top, width, height),
            out var point);

        Assert.Equal(expected, result);
        Assert.Equal(new Point(expectedX, expectedY), point);
    }

    [Fact]
    public void TryBuildConversationClickPoints_returns_content_fallback_and_center_points()
    {
        var result = DingTalkMessageNavigator.TryBuildConversationClickPoints(
            new Rectangle(100, 200, 260, 72),
            out var points);

        Assert.True(result);
        Assert.Equal(
            new[]
            {
                new Point(204, 236),
                new Point(165, 236),
                new Point(230, 236),
            },
            points);
    }

    [Fact]
    public void TryBuildConversationListClickPoints_targets_first_visible_row_in_container()
    {
        var result = DingTalkMessageNavigator.TryBuildConversationListClickPoints(
            new Rectangle(100, 200, 296, 789),
            out var points);

        Assert.True(result);
        Assert.Equal(
            new[]
            {
                new Point(218, 236),
                new Point(174, 236),
                new Point(248, 236),
            },
            points);
    }

    [Fact]
    public void TryBuildMessageNavigatorFallbackClickPoints_targets_top_navigation_slot()
    {
        var result = DingTalkMessageNavigator.TryBuildMessageNavigatorFallbackClickPoints(
            new Rectangle(20, 80, 72, 600),
            out var points);

        Assert.True(result);
        Assert.Equal(
            new[]
            {
                new Point(56, 155),
                new Point(56, 139),
                new Point(56, 171),
            },
            points);
    }

    [Fact]
    public void TryBuildMessageNavigatorElementClickPoints_targets_actual_message_button_bounds()
    {
        var result = DingTalkMessageNavigator.TryBuildMessageNavigatorElementClickPoints(
            new Rectangle(24, 132, 72, 48),
            out var points);

        Assert.True(result);
        Assert.Equal(
            new[]
            {
                new Point(60, 156),
                new Point(60, 144),
                new Point(60, 168),
            },
            points);
    }

    [Theory]
    [InlineData(0, 600)]
    [InlineData(72, 0)]
    public void TryBuildMessageNavigatorFallbackClickPoints_rejects_empty_bounds(
        int width,
        int height)
    {
        var result = DingTalkMessageNavigator.TryBuildMessageNavigatorFallbackClickPoints(
            new Rectangle(20, 80, width, height),
            out var points);

        Assert.False(result);
        Assert.Empty(points);
    }
}
