using System.Runtime.ExceptionServices;
using System.Runtime.InteropServices;
using DingTalkWindowsHost.Automation.WindowHost;
using DingTalkWindowsHost.Contracts.Models;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class WindowHostTests
{
    [Fact]
    public void ChooseMainWindow_prefers_largest_eligible_titled_window()
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x101),
                Title: "Splash",
                ClassName: "DingTalkSplash",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 480,
                Height: 320,
                ZOrder: 3),
            new WindowCandidate(
                Handle: new IntPtr(0x102),
                Title: "Main Workspace",
                ClassName: "DingTalkMain",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1280,
                Height: 820,
                ZOrder: 4),
            new WindowCandidate(
                Handle: new IntPtr(0x103),
                Title: "Aux",
                ClassName: "DingTalkAux",
                IsVisible: false,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1400,
                Height: 900,
                ZOrder: 2),
        };

        var result = locator.ChooseMainWindow(candidates);

        Assert.NotNull(result);
        Assert.Equal(new IntPtr(0x102), result!.Handle);
    }

    [Fact]
    public void ChooseMainWindow_ignores_tool_windows_and_children()
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x201),
                Title: "Toolbar",
                ClassName: "DingTalkToolbar",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: true,
                Width: 1024,
                Height: 768,
                ZOrder: 1),
            new WindowCandidate(
                Handle: new IntPtr(0x202),
                Title: "Child Content",
                ClassName: "DingTalkChild",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: false,
                Width: 1200,
                Height: 800,
                ZOrder: 2),
            new WindowCandidate(
                Handle: new IntPtr(0x203),
                Title: "Primary",
                ClassName: "DingTalkMain",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1100,
                Height: 760,
                ZOrder: 3),
        };

        var result = locator.ChooseMainWindow(candidates);

        Assert.NotNull(result);
        Assert.Equal(new IntPtr(0x203), result!.Handle);
    }

    [Fact]
    public void ChooseMainWindow_returns_null_when_no_candidate_is_eligible()
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: IntPtr.Zero,
                Title: "Missing",
                ClassName: "DingTalkMain",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1200,
                Height: 800,
                ZOrder: 1),
            new WindowCandidate(
                Handle: new IntPtr(0x301),
                Title: "Hidden",
                ClassName: "DingTalkMain",
                IsVisible: false,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1200,
                Height: 800,
                ZOrder: 2),
            new WindowCandidate(
                Handle: new IntPtr(0x302),
                Title: "Tiny",
                ClassName: "DingTalkMini",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 100,
                Height: 100,
                ZOrder: 3),
        };

        var result = locator.ChooseMainWindow(candidates);

        Assert.Null(result);
    }

    [Fact]
    public void ChooseMainWindow_prefers_visible_qt_workspace_over_empty_chrome_container()
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x351),
                Title: "",
                ClassName: "Chrome_WidgetWin_0",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 2000,
                Height: 1400,
                ZOrder: 1,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x352),
                Title: "\u9489\u9489",
                ClassName: "DingTalkMain",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1100,
                Height: 760,
                ZOrder: 2,
                ProcessName: "DingTalk"),
        };

        var result = locator.ChooseMainWindow(candidates);

        Assert.NotNull(result);
        Assert.Equal(new IntPtr(0x352), result!.Handle);
    }

    [Fact]
    public void ChooseMainWindow_prefers_visible_qt_workspace_over_ding_chat_child_window()
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x361),
                Title: "\u9489\u9489",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1280,
                Height: 900,
                ZOrder: 1,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x362),
                Title: "",
                ClassName: "DingChatWnd",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: false,
                Width: 959,
                Height: 600,
                ZOrder: 2,
                ProcessName: "DingTalk"),
        };

        var result = locator.ChooseMainWindow(candidates);

        Assert.NotNull(result);
        Assert.Equal(new IntPtr(0x361), result!.Handle);
    }

    [Fact]
    public void ChooseMainWindow_prefers_visible_dingtalk_chat_module_over_empty_chat_container()
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x381),
                Title: "",
                ClassName: "DingChatWnd",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: false,
                Width: 0,
                Height: 0,
                ZOrder: 1,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x382),
                Title: "DTIMChatModule",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: false,
                Width: 885,
                Height: 563,
                ZOrder: 2,
                ProcessName: "DingTalk"),
        };

        var result = locator.ChooseMainWindow(candidates);

        Assert.NotNull(result);
        Assert.Equal(new IntPtr(0x382), result!.Handle);
    }

    [Fact]
    public void ChooseMainWindow_falls_back_to_standard_frame_when_chat_children_have_no_size()
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x391),
                Title: "\u9489\u9489",
                ClassName: "StandardFrame_DingTalk",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 159,
                Height: 27,
                ZOrder: 1,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x392),
                Title: "",
                ClassName: "DingChatWnd",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: false,
                Width: 0,
                Height: 0,
                ZOrder: 2,
                ProcessName: "DingTalk"),
        };

        var result = locator.ChooseMainWindow(candidates);

        Assert.NotNull(result);
        Assert.Equal(new IntPtr(0x391), result!.Handle);
    }

    [Fact]
    public void ChooseMainWindow_prefers_visible_qt_workspace_over_empty_standard_frame()
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x395),
                Title: "DingTalk",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1280,
                Height: 900,
                ZOrder: 0,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x396),
                Title: "\u9489\u9489",
                ClassName: "StandardFrame_DingTalk",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 0,
                Height: 0,
                ZOrder: 1,
                ProcessName: "DingTalk"),
        };

        var result = locator.ChooseMainWindow(candidates);

        Assert.NotNull(result);
        Assert.Equal(new IntPtr(0x395), result!.Handle);
    }

    [Theory]
    [InlineData("DTIMChatAtWndView", "Form")]
    [InlineData("DTIMChatAtRoleWndView", "Form")]
    [InlineData("DTIMChatAtListView", "Group members")]
    [InlineData("client_ding::AiAssistTrayMenuPanelView", "Form")]
    [InlineData("Qt51511QWindowIcon", "AiAssistTrayMenuPanel")]
    public void ChooseMainWindow_ignores_transient_overlay_windows_and_prefers_main_frame(
        string overlayClassName,
        string overlayTitle)
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x397),
                Title: overlayTitle,
                ClassName: overlayClassName,
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1600,
                Height: 1000,
                ZOrder: 0,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x398),
                Title: "\u9489\u9489",
                ClassName: "StandardFrame_DingTalk",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 900,
                Height: 700,
                ZOrder: 1,
                ProcessName: "DingTalk"),
        };

        var result = locator.ChooseMainWindow(candidates);

        Assert.NotNull(result);
        Assert.Equal(new IntPtr(0x398), result!.Handle);
    }

    [Theory]
    [InlineData("DTIMChatAtWndView", "Form")]
    [InlineData("client_ding::AiAssistTrayMenuPanelView", "Form")]
    [InlineData("Qt51511QWindowIcon", "AiAssistTrayMenuPanel")]
    public void ChooseMainWindow_returns_null_when_only_transient_overlay_candidates_exist(
        string overlayClassName,
        string overlayTitle)
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x399),
                Title: overlayTitle,
                ClassName: overlayClassName,
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1600,
                Height: 1000,
                ZOrder: 0,
                ProcessName: "DingTalk"),
        };

        var result = locator.ChooseMainWindow(candidates);

        Assert.Null(result);
    }

    [Fact]
    public void ChooseMainWindow_uses_visible_ding_chat_child_as_fallback_over_empty_chrome_container()
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x371),
                Title: "",
                ClassName: "DingChatWnd",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: false,
                Width: 2000,
                Height: 1400,
                ZOrder: 1,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x372),
                Title: "",
                ClassName: "Chrome_WidgetWin_0",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1280,
                Height: 720,
                ZOrder: 2,
                ProcessName: "DingTalk"),
        };

        var result = locator.ChooseMainWindow(candidates);

        Assert.NotNull(result);
        Assert.Equal(new IntPtr(0x371), result!.Handle);
    }

    [Fact]
    public void ChooseMainWindow_prefers_visible_top_level_ding_chat_window_over_main_qt_frame()
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x373),
                Title: "\u9489\u9489",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1280,
                Height: 900,
                ZOrder: 1,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x374),
                Title: "",
                ClassName: "DingChatWnd",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1095,
                Height: 843,
                ZOrder: 2,
                ProcessName: "DingTalk"),
        };

        var result = locator.ChooseMainWindow(candidates);

        Assert.NotNull(result);
        Assert.Equal(new IntPtr(0x374), result!.Handle);
    }

    [Fact]
    public void ChooseMainWindow_prefers_visible_top_level_ding_chat_window_even_when_initial_size_is_zero()
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x377),
                Title: "\u9489\u9489",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1280,
                Height: 900,
                ZOrder: 1,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x378),
                Title: string.Empty,
                ClassName: "DingChatWnd",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 0,
                Height: 0,
                ZOrder: 2,
                ProcessName: "DingTalk"),
        };

        var result = locator.ChooseMainWindow(candidates);

        Assert.NotNull(result);
        Assert.Equal(new IntPtr(0x378), result!.Handle);
    }

    [Fact]
    public void ChooseMainWindow_rejects_zero_sized_ding_chat_child_window()
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x379),
                Title: "\u9489\u9489",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1280,
                Height: 900,
                ZOrder: 1,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x37A),
                Title: string.Empty,
                ClassName: "DingChatWnd",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: false,
                Width: 0,
                Height: 0,
                ZOrder: 2,
                ProcessName: "DingTalk"),
        };

        var result = locator.ChooseMainWindow(candidates);

        Assert.NotNull(result);
        Assert.Equal(new IntPtr(0x379), result!.Handle);
    }

    [Theory]
    [InlineData("CefBrowserWindow")]
    [InlineData("Chrome_WidgetWin_1")]
    public void ChooseMainWindow_prefers_visible_qt_main_frame_over_browser_child_container(
        string browserClassName)
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x375),
                Title: string.Empty,
                ClassName: browserClassName,
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: false,
                Width: 1280,
                Height: 900,
                ZOrder: 1,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x376),
                Title: "\u9489\u9489",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1280,
                Height: 900,
                ZOrder: 2,
                ProcessName: "DingTalk"),
        };

        var result = locator.ChooseMainWindow(candidates);

        Assert.NotNull(result);
        Assert.Equal(new IntPtr(0x376), result!.Handle);
    }

    [Theory]
    [InlineData("", "", "DingTalk")]
    [InlineData("\u9489\u9489", "", "")]
    public void IsLikelyDingTalkWindow_accepts_dingtalk_identity_signals(
        string title,
        string className,
        string processName)
    {
        var candidate = new WindowCandidate(
            Handle: new IntPtr(0x401),
            Title: title,
            ClassName: className,
            IsVisible: true,
            IsEnabled: true,
            IsTopLevel: true,
            IsToolWindow: false,
            Width: 1200,
            Height: 800,
            ZOrder: 1,
            ProcessName: processName);

        Assert.True(DingTalkWindowLocator.IsLikelyDingTalkWindow(candidate));
    }

    [Fact]
    public void IsLikelyDingTalkWindow_rejects_host_shell_window()
    {
        var candidate = new WindowCandidate(
            Handle: new IntPtr(0x402),
            Title: "DingTalk Windows Host",
            ClassName: "HwndWrapper[DingTalkWindowsHost.App]",
            IsVisible: true,
            IsEnabled: true,
            IsTopLevel: true,
            IsToolWindow: false,
            Width: 1200,
            Height: 800,
            ZOrder: 1,
            ProcessName: "DingTalkWindowsHost.App");

        Assert.False(DingTalkWindowLocator.IsLikelyDingTalkWindow(candidate));
    }

    [Fact]
    public void ChooseMainWindow_prefers_dingtalk_candidate_over_larger_foreign_window()
    {
        var locator = new DingTalkWindowLocator(static () => new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x501),
                Title: "Browser",
                ClassName: "Chrome_WidgetWin_1",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1900,
                Height: 1000,
                ZOrder: 1,
                ProcessName: "chrome"),
            new WindowCandidate(
                Handle: new IntPtr(0x502),
                Title: "\u9489\u9489",
                ClassName: "DingTalkMain",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1000,
                Height: 720,
                ZOrder: 2,
                ProcessName: "DingTalk"),
        });

        var result = locator.ChooseMainWindow(locator.GetWindowCandidates());

        Assert.NotNull(result);
        Assert.Equal(new IntPtr(0x502), result!.Handle);
    }

    [Fact]
    public void ChooseMainWindow_can_recover_hidden_top_level_dingtalk_workspace()
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x581),
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
        };

        var result = locator.ChooseMainWindow(candidates);

        Assert.NotNull(result);
        Assert.Equal(new IntPtr(0x581), result!.Handle);
    }

    [Fact]
    public void ChooseMainWindow_rejects_visible_small_dingtalk_qt_helper_frame_after_restore()
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x583),
                Title: "DingTalk",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 218,
                Height: 247,
                ZOrder: 1,
                ProcessName: "DingTalk"),
        };

        var result = locator.ChooseMainWindow(candidates);

        Assert.Null(result);
    }

    [Fact]
    public void ChooseMainWindow_prefers_visible_dingtalk_qt_main_frame_over_hidden_workspace()
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x584),
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
            new WindowCandidate(
                Handle: new IntPtr(0x585),
                Title: "\u9489\u9489",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1270,
                Height: 800,
                ZOrder: 2,
                ProcessName: "DingTalk"),
        };

        var result = locator.ChooseMainWindow(candidates);

        Assert.NotNull(result);
        Assert.Equal(new IntPtr(0x585), result!.Handle);
    }

    [Fact]
    public void ChooseMainWindow_accepts_visible_top_level_dingtalk_qt_main_frame_with_zero_reported_size()
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x586),
                Title: "\u9489\u9489",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 0,
                Height: 0,
                ZOrder: 1,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x587),
                Title: "ConvTabListView",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: false,
                IsToolWindow: false,
                Width: 296,
                Height: 789,
                ZOrder: 2,
                ProcessName: "DingTalk"),
        };

        var result = locator.ChooseMainWindow(candidates);

        Assert.NotNull(result);
        Assert.Equal(new IntPtr(0x586), result!.Handle);
    }

    [Fact]
    public void ChooseMainWindow_can_recover_hidden_tool_dingtalk_workspace()
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var candidates = new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x582),
                Title: "DingTalk",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: false,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: true,
                Width: 819,
                Height: 570,
                ZOrder: 1,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x583),
                Title: "Form",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: false,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: true,
                Width: 300,
                Height: 450,
                ZOrder: 2,
                ProcessName: "DingTalk"),
        };

        var result = locator.ChooseMainWindow(candidates);

        Assert.NotNull(result);
        Assert.Equal(new IntPtr(0x582), result!.Handle);
    }

    [Fact]
    public void WindowSupervisor_keeps_existing_attachment_when_reparented_window_is_not_enumerated()
    {
        var candidate = new WindowCandidate(
            Handle: new IntPtr(0x601),
            Title: "\u9489\u9489",
            ClassName: "StandardFrame_DingTalk",
            IsVisible: true,
            IsEnabled: true,
            IsTopLevel: true,
            IsToolWindow: false,
            Width: 900,
            Height: 700,
            ZOrder: 1,
            ProcessName: "DingTalk");
        var candidatesByTick = new Queue<IReadOnlyList<WindowCandidate>>();
        candidatesByTick.Enqueue(new[] { candidate });
        candidatesByTick.Enqueue(Array.Empty<WindowCandidate>());
        var locator = new DingTalkWindowLocator(() => candidatesByTick.Count == 0
            ? Array.Empty<WindowCandidate>()
            : candidatesByTick.Dequeue());
        var embedder = new FakeWindowEmbedder();
        var supervisor = new WindowSupervisor(locator, embedder);

        supervisor.RequestStart();
        var first = supervisor.Tick(new IntPtr(0x701), new HostSurfaceBounds(1024, 720));
        var second = supervisor.Tick(new IntPtr(0x701), new HostSurfaceBounds(1024, 720));

        Assert.Equal(WindowSupervisorShellState.Attached, first.ShellState);
        Assert.Equal(WindowSupervisorShellState.Attached, second.ShellState);
        Assert.Equal(new IntPtr(0x601), second.CurrentHwnd);
        Assert.Equal(0, embedder.DetachCount);
    }

    [Fact]
    public void WindowSupervisor_keeps_existing_attachment_when_another_candidate_appears()
    {
        var firstCandidate = new WindowCandidate(
            Handle: new IntPtr(0x611),
            Title: "DingTalk",
            ClassName: "Qt51511QWindowIcon",
            IsVisible: false,
            IsEnabled: true,
            IsTopLevel: true,
            IsToolWindow: false,
            Width: 818,
            Height: 647,
            ZOrder: 1,
            ProcessName: "DingTalk");
        var secondCandidate = firstCandidate with
        {
            Handle = new IntPtr(0x612),
            ZOrder = 0,
        };
        var candidatesByTick = new Queue<IReadOnlyList<WindowCandidate>>();
        candidatesByTick.Enqueue(new[] { firstCandidate });
        candidatesByTick.Enqueue(new[] { secondCandidate });
        var locator = new DingTalkWindowLocator(() => candidatesByTick.Count == 0
            ? new[] { secondCandidate }
            : candidatesByTick.Dequeue());
        var embedder = new FakeWindowEmbedder();
        var supervisor = new WindowSupervisor(locator, embedder);

        supervisor.RequestStart();
        var first = supervisor.Tick(new IntPtr(0x711), new HostSurfaceBounds(1024, 720));
        var second = supervisor.Tick(new IntPtr(0x711), new HostSurfaceBounds(1024, 720));

        Assert.Equal(WindowSupervisorShellState.Attached, first.ShellState);
        Assert.Equal(WindowSupervisorShellState.Attached, second.ShellState);
        Assert.Equal(new IntPtr(0x611), second.CurrentHwnd);
        Assert.Equal(1, embedder.AttachCount);
    }

    [Fact]
    public void WindowSupervisor_attaches_visible_zero_sized_dingtalk_qt_main_frame()
    {
        var candidate = new WindowCandidate(
            Handle: new IntPtr(0x613),
            Title: "\u9489\u9489",
            ClassName: "Qt51511QWindowIcon",
            IsVisible: true,
            IsEnabled: true,
            IsTopLevel: true,
            IsToolWindow: false,
            Width: 0,
            Height: 0,
            ZOrder: 1,
            ProcessName: "DingTalk");
        var locator = new DingTalkWindowLocator(() => new[] { candidate });
        var embedder = new FakeWindowEmbedder();
        var supervisor = new WindowSupervisor(locator, embedder);

        supervisor.RequestStart();
        var snapshot = supervisor.Tick(new IntPtr(0x713), new HostSurfaceBounds(1024, 720));

        Assert.Equal(WindowSupervisorShellState.Attached, snapshot.ShellState);
        Assert.Equal(WindowSupervisorAction.Attached, snapshot.LastAction);
        Assert.Equal(new IntPtr(0x613), snapshot.CurrentHwnd);
        Assert.Equal(1, embedder.AttachCount);
    }

    [Fact]
    public void WindowSupervisor_switches_to_visible_candidate_when_current_attachment_is_stale()
    {
        var staleCandidate = new WindowCandidate(
            Handle: new IntPtr(0x615),
            Title: "DingTalk",
            ClassName: "Qt51511QWindowIcon",
            IsVisible: false,
            IsEnabled: true,
            IsTopLevel: true,
            IsToolWindow: false,
            Width: 818,
            Height: 647,
            ZOrder: 1,
            ProcessName: "DingTalk");
        var visibleCandidate = staleCandidate with
        {
            Handle = new IntPtr(0x616),
            Title = "\u9489\u9489",
            ClassName = "StandardFrame_DingTalk",
            IsVisible = true,
            Width = 900,
            Height = 700,
            ZOrder = 0,
        };
        var candidatesByTick = new Queue<IReadOnlyList<WindowCandidate>>();
        candidatesByTick.Enqueue(new[] { staleCandidate });
        candidatesByTick.Enqueue(new[] { visibleCandidate });
        var locator = new DingTalkWindowLocator(() => candidatesByTick.Count == 0
            ? new[] { visibleCandidate }
            : candidatesByTick.Dequeue());
        var embedder = new FakeWindowEmbedder();
        var supervisor = new WindowSupervisor(locator, embedder);

        supervisor.RequestStart();
        var first = supervisor.Tick(new IntPtr(0x716), new HostSurfaceBounds(1024, 720));
        var second = supervisor.Tick(new IntPtr(0x716), new HostSurfaceBounds(1024, 720));

        Assert.Equal(WindowSupervisorShellState.Attached, first.ShellState);
        Assert.Equal(WindowSupervisorShellState.Attached, second.ShellState);
        Assert.Equal(WindowSupervisorAction.Reattached, second.LastAction);
        Assert.Equal(new IntPtr(0x616), second.CurrentHwnd);
        Assert.Equal(2, embedder.AttachCount);
    }

    [Fact]
    public void WindowSupervisor_switches_from_chromium_container_to_visible_ding_chat_window()
    {
        var chromiumContainer = new WindowCandidate(
            Handle: new IntPtr(0x617),
            Title: string.Empty,
            ClassName: "CefBrowserWindow",
            IsVisible: true,
            IsEnabled: true,
            IsTopLevel: false,
            IsToolWindow: false,
            Width: 1280,
            Height: 900,
            ZOrder: 1,
            ProcessName: "DingTalk");
        var dingChatWindow = new WindowCandidate(
            Handle: new IntPtr(0x618),
            Title: string.Empty,
            ClassName: "DingChatWnd",
            IsVisible: true,
            IsEnabled: true,
            IsTopLevel: true,
            IsToolWindow: false,
            Width: 1280,
            Height: 900,
            ZOrder: 0,
            ProcessName: "DingTalk");
        var candidatesByTick = new Queue<IReadOnlyList<WindowCandidate>>();
        candidatesByTick.Enqueue(new[] { chromiumContainer });
        candidatesByTick.Enqueue(new[] { chromiumContainer, dingChatWindow });
        var locator = new DingTalkWindowLocator(() => candidatesByTick.Count == 0
            ? new[] { chromiumContainer, dingChatWindow }
            : candidatesByTick.Dequeue());
        var embedder = new FakeWindowEmbedder();
        var supervisor = new WindowSupervisor(locator, embedder);

        supervisor.RequestStart();
        var first = supervisor.Tick(new IntPtr(0x718), new HostSurfaceBounds(1024, 720));
        var second = supervisor.Tick(new IntPtr(0x718), new HostSurfaceBounds(1024, 720));

        Assert.Equal(WindowSupervisorShellState.Attached, first.ShellState);
        Assert.Equal(new IntPtr(0x617), first.CurrentHwnd);
        Assert.Equal(WindowSupervisorAction.Reattached, second.LastAction);
        Assert.Equal(new IntPtr(0x618), second.CurrentHwnd);
        Assert.Equal(2, embedder.AttachCount);
    }

    [Fact]
    public void WindowSupervisor_switches_from_qt_main_frame_to_zero_sized_top_level_ding_chat_window()
    {
        var qtMainFrame = new WindowCandidate(
            Handle: new IntPtr(0x619),
            Title: "\u9489\u9489",
            ClassName: "Qt51511QWindowIcon",
            IsVisible: true,
            IsEnabled: true,
            IsTopLevel: true,
            IsToolWindow: false,
            Width: 1280,
            Height: 900,
            ZOrder: 1,
            ProcessName: "DingTalk");
        var dingChatWindow = new WindowCandidate(
            Handle: new IntPtr(0x61A),
            Title: string.Empty,
            ClassName: "DingChatWnd",
            IsVisible: true,
            IsEnabled: true,
            IsTopLevel: true,
            IsToolWindow: false,
            Width: 0,
            Height: 0,
            ZOrder: 0,
            ProcessName: "DingTalk");
        var candidatesByTick = new Queue<IReadOnlyList<WindowCandidate>>();
        candidatesByTick.Enqueue(new[] { qtMainFrame });
        candidatesByTick.Enqueue(new[] { qtMainFrame, dingChatWindow });
        var locator = new DingTalkWindowLocator(() => candidatesByTick.Count == 0
            ? new[] { qtMainFrame, dingChatWindow }
            : candidatesByTick.Dequeue());
        var embedder = new FakeWindowEmbedder();
        var supervisor = new WindowSupervisor(locator, embedder);

        supervisor.RequestStart();
        var first = supervisor.Tick(new IntPtr(0x719), new HostSurfaceBounds(1024, 720));
        var second = supervisor.Tick(new IntPtr(0x719), new HostSurfaceBounds(1024, 720));

        Assert.Equal(WindowSupervisorShellState.Attached, first.ShellState);
        Assert.Equal(new IntPtr(0x619), first.CurrentHwnd);
        Assert.Equal(WindowSupervisorAction.Reattached, second.LastAction);
        Assert.Equal(new IntPtr(0x61A), second.CurrentHwnd);
        Assert.Equal(2, embedder.AttachCount);
    }

    [Fact]
    public void WindowSupervisor_restores_previous_attachment_before_selecting_window()
    {
        var candidate = new WindowCandidate(
            Handle: new IntPtr(0x621),
            Title: "DingTalk",
            ClassName: "Qt51511QWindowIcon",
            IsVisible: false,
            IsEnabled: true,
            IsTopLevel: true,
            IsToolWindow: false,
            Width: 818,
            Height: 647,
            ZOrder: 1,
            ProcessName: "DingTalk");
        var locator = new DingTalkWindowLocator(() => new[] { candidate });
        var embedder = new FakeWindowEmbedder
        {
            RestorePreviousAttachmentResult = true,
        };
        var supervisor = new WindowSupervisor(locator, embedder);

        supervisor.RequestStart();
        var snapshot = supervisor.Tick(new IntPtr(0x721), new HostSurfaceBounds(1024, 720));

        Assert.Equal(WindowSupervisorShellState.Attached, snapshot.ShellState);
        Assert.Equal(1, embedder.RestorePreviousAttachmentCount);
        Assert.Equal(1, embedder.AttachCount);
    }

    [Fact]
    public void WindowSupervisor_switches_from_stale_restored_attachment_to_selected_hidden_workspace()
    {
        var selectedCandidate = new WindowCandidate(
            Handle: new IntPtr(0x622),
            Title: "DingTalk",
            ClassName: "Qt51511QWindowIcon",
            IsVisible: false,
            IsEnabled: true,
            IsTopLevel: true,
            IsToolWindow: false,
            Width: 818,
            Height: 647,
            ZOrder: 1,
            ProcessName: "DingTalk");
        var locator = new DingTalkWindowLocator(() => new[] { selectedCandidate });
        var embedder = new FakeWindowEmbedder
        {
            RestorePreviousAttachmentResult = true,
        };
        embedder.Attach(new IntPtr(0x620), new IntPtr(0x722), new HostSurfaceBounds(1024, 720));
        var supervisor = new WindowSupervisor(locator, embedder);

        supervisor.RequestStart();
        var snapshot = supervisor.Tick(new IntPtr(0x722), new HostSurfaceBounds(1024, 720));

        Assert.Equal(WindowSupervisorShellState.Attached, snapshot.ShellState);
        Assert.Equal(WindowSupervisorAction.Reattached, snapshot.LastAction);
        Assert.Equal(new IntPtr(0x622), snapshot.CurrentHwnd);
        Assert.Equal(2, embedder.AttachCount);
    }

    [Fact]
    public void WindowSupervisor_stop_reports_stopped_when_detach_throws()
    {
        var candidate = new WindowCandidate(
            Handle: new IntPtr(0x631),
            Title: "\u9489\u9489",
            ClassName: "StandardFrame_DingTalk",
            IsVisible: true,
            IsEnabled: true,
            IsTopLevel: true,
            IsToolWindow: false,
            Width: 900,
            Height: 700,
            ZOrder: 1,
            ProcessName: "DingTalk");
        var locator = new DingTalkWindowLocator(() => new[] { candidate });
        var embedder = new FakeWindowEmbedder();
        var supervisor = new WindowSupervisor(locator, embedder);

        supervisor.RequestStart();
        var attached = supervisor.Tick(new IntPtr(0x731), new HostSurfaceBounds(1024, 720));
        embedder.ThrowOnDetach = true;
        supervisor.RequestStop();

        var stopped = supervisor.Tick(new IntPtr(0x731), new HostSurfaceBounds(1024, 720));

        Assert.Equal(WindowSupervisorShellState.Attached, attached.ShellState);
        Assert.Equal(WindowSupervisorShellState.Stopped, stopped.ShellState);
        Assert.Equal(WindowSupervisorAction.Detached, stopped.LastAction);
        Assert.Equal(IntPtr.Zero, stopped.CurrentHwnd);
        Assert.Contains("Detach failed", stopped.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void WindowDiagnostics_reports_no_dingtalk_process_when_no_candidates_exist()
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());
        var diagnostics = new WindowDiagnosticsProvider(locator).GetCandidateDiagnostics(limit: 10);

        Assert.Equal(WindowCandidateHealth.NoDingTalkProcess, diagnostics.Health);
        Assert.Equal(0, diagnostics.TotalDingTalkCandidates);
        Assert.Equal("", diagnostics.SelectedHwnd);
        Assert.Contains("Launch DingTalk", diagnostics.Recommendation, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void WindowDiagnostics_reports_hosted_candidate_when_runtime_handle_is_attached()
    {
        var locator = new DingTalkWindowLocator(static () => new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x641),
                Title: "GDI+ Window (DingTalk.exe)",
                ClassName: "GDI+ Hook Window Class",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1,
                Height: 1,
                ZOrder: 1,
                ProcessName: "DingTalk"),
        });

        var diagnostics = new WindowDiagnosticsProvider(
                locator,
                static () => new IntPtr(0x642))
            .GetCandidateDiagnostics(limit: 10);

        Assert.Equal(WindowCandidateHealth.HostedCandidate, diagnostics.Health);
        Assert.Equal("0x642", diagnostics.SelectedHwnd);
        Assert.Contains("hosted", diagnostics.Recommendation, StringComparison.OrdinalIgnoreCase);
        Assert.Equal(WindowCandidateRejectionReason.TooSmall, diagnostics.Candidates[0].RejectionReason);
    }

    [Fact]
    public void WindowDiagnostics_prefers_hosted_handle_over_locator_selected_candidate()
    {
        var locator = new DingTalkWindowLocator(static () => new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x645),
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
            new WindowCandidate(
                Handle: new IntPtr(0x646),
                Title: "\u9489\u9489",
                ClassName: "StandardFrame_DingTalk",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 0,
                Height: 0,
                ZOrder: 2,
                ProcessName: "DingTalk"),
        });

        var diagnostics = new WindowDiagnosticsProvider(
                locator,
                static () => new IntPtr(0x646))
            .GetCandidateDiagnostics(limit: 10);

        Assert.Equal(WindowCandidateHealth.HostedCandidate, diagnostics.Health);
        Assert.Equal("0x646", diagnostics.SelectedHwnd);
    }

    [Fact]
    public void WindowDiagnostics_reports_hosted_candidate_when_no_desktop_candidates_are_visible()
    {
        var locator = new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>());

        var diagnostics = new WindowDiagnosticsProvider(
                locator,
                static () => new IntPtr(0x643))
            .GetCandidateDiagnostics(limit: 10);

        Assert.Equal(WindowCandidateHealth.HostedCandidate, diagnostics.Health);
        Assert.Equal("0x643", diagnostics.SelectedHwnd);
        Assert.Equal(0, diagnostics.TotalDingTalkCandidates);
    }

    [Fact]
    public void WindowDiagnostics_reports_ready_when_visible_candidate_is_selected()
    {
        var locator = new DingTalkWindowLocator(static () => new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x801),
                Title: "\u9489\u9489",
                ClassName: "StandardFrame_DingTalk",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 900,
                Height: 700,
                ZOrder: 1,
                ProcessName: "DingTalk"),
        });

        var diagnostics = new WindowDiagnosticsProvider(locator).GetCandidateDiagnostics(limit: 10);

        Assert.Equal(WindowCandidateHealth.Ready, diagnostics.Health);
        Assert.Equal("0x801", diagnostics.SelectedHwnd);
        Assert.Equal(1, diagnostics.TotalDingTalkCandidates);
        Assert.Equal(1, diagnostics.VisibleCandidates);
        Assert.Contains("Ready", diagnostics.Recommendation, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void WindowDiagnostics_reports_hidden_workspace_only_for_recoverable_hidden_qt_workspace()
    {
        var locator = new DingTalkWindowLocator(static () => new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x811),
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
        });

        var diagnostics = new WindowDiagnosticsProvider(locator).GetCandidateDiagnostics(limit: 10);

        Assert.Equal(WindowCandidateHealth.HiddenWorkspaceOnly, diagnostics.Health);
        Assert.Equal("0x811", diagnostics.SelectedHwnd);
        Assert.Equal(1, diagnostics.HiddenWorkspaceCandidates);
        Assert.Contains("hidden workspace", diagnostics.Recommendation, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void WindowDiagnostics_reports_hidden_workspace_for_recoverable_tool_qt_workspace()
    {
        var locator = new DingTalkWindowLocator(static () => new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x812),
                Title: "DingTalk",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: false,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: true,
                Width: 819,
                Height: 570,
                ZOrder: 1,
                ProcessName: "DingTalk"),
        });

        var diagnostics = new WindowDiagnosticsProvider(locator).GetCandidateDiagnostics(limit: 10);

        Assert.Equal(WindowCandidateHealth.HiddenWorkspaceOnly, diagnostics.Health);
        Assert.Equal("0x812", diagnostics.SelectedHwnd);
        Assert.Equal(1, diagnostics.HiddenWorkspaceCandidates);
        Assert.Equal(WindowCandidateRejectionReason.None, diagnostics.Candidates[0].RejectionReason);
    }

    [Theory]
    [InlineData("MsgBox")]
    [InlineData("OperationTaskDlg")]
    public void WindowDiagnostics_reports_blocking_dialog_for_dialog_like_candidates(string className)
    {
        var locator = new DingTalkWindowLocator(() => new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x821),
                Title: "Restart required",
                ClassName: className,
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 420,
                Height: 240,
                ZOrder: 0,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x822),
                Title: "\u9489\u9489",
                ClassName: "StandardFrame_DingTalk",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 900,
                Height: 700,
                ZOrder: 1,
                ProcessName: "DingTalk"),
        });

        var diagnostics = new WindowDiagnosticsProvider(locator).GetCandidateDiagnostics(limit: 10);

        Assert.Equal(WindowCandidateHealth.BlockedByDialog, diagnostics.Health);
        Assert.Equal(1, diagnostics.BlockingDialogCandidates);
        Assert.Contains("dialog", diagnostics.Recommendation, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void WindowDiagnostics_reports_no_eligible_window_when_only_small_candidates_exist()
    {
        var locator = new DingTalkWindowLocator(static () => new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x831),
                Title: "\u9489\u9489",
                ClassName: "DingTalkMini",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 120,
                Height: 80,
                ZOrder: 1,
                ProcessName: "DingTalk"),
        });

        var diagnostics = new WindowDiagnosticsProvider(locator).GetCandidateDiagnostics(limit: 10);

        Assert.Equal(WindowCandidateHealth.NoEligibleWindow, diagnostics.Health);
        Assert.Equal(1, diagnostics.TotalDingTalkCandidates);
        Assert.Equal("", diagnostics.SelectedHwnd);
        Assert.Contains("eligible", diagnostics.Recommendation, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void WindowDiagnostics_reports_transient_overlay_rejection_reason()
    {
        var locator = new DingTalkWindowLocator(static () => new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x835),
                Title: "Form",
                ClassName: "DTIMChatAtWndView",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1600,
                Height: 1000,
                ZOrder: 1,
                ProcessName: "DingTalk"),
        });

        var diagnostics = new WindowDiagnosticsProvider(locator).GetCandidateDiagnostics(limit: 10);

        Assert.Equal(WindowCandidateHealth.NoEligibleWindow, diagnostics.Health);
        Assert.Equal("", diagnostics.SelectedHwnd);
        Assert.Equal(WindowCandidateRejectionReason.TransientOverlay, diagnostics.Candidates[0].RejectionReason);
    }

    [Fact]
    public void WindowDiagnostics_reports_hidden_overlay_as_transient_not_hidden_workspace()
    {
        var locator = new DingTalkWindowLocator(static () => new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x836),
                Title: "DingTalk",
                ClassName: "DTIMChatAtRoleWndView",
                IsVisible: false,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 818,
                Height: 647,
                ZOrder: 1,
                ProcessName: "DingTalk"),
        });

        var diagnostics = new WindowDiagnosticsProvider(locator).GetCandidateDiagnostics(limit: 10);

        Assert.Equal(WindowCandidateHealth.NoEligibleWindow, diagnostics.Health);
        Assert.Equal(0, diagnostics.HiddenWorkspaceCandidates);
        Assert.Equal(WindowCandidateRejectionReason.TransientOverlay, diagnostics.Candidates[0].RejectionReason);
    }

    [Fact]
    public void WindowDiagnostics_does_not_count_hidden_tool_windows_as_hidden_workspace()
    {
        var locator = new DingTalkWindowLocator(static () => new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x841),
                Title: "Form",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: false,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: true,
                Width: 300,
                Height: 450,
                ZOrder: 1,
                ProcessName: "DingTalk"),
        });

        var diagnostics = new WindowDiagnosticsProvider(locator).GetCandidateDiagnostics(limit: 10);

        Assert.Equal(WindowCandidateHealth.NoEligibleWindow, diagnostics.Health);
        Assert.Equal(0, diagnostics.HiddenWorkspaceCandidates);
    }

    [Fact]
    public void WindowDiagnostics_explains_candidate_attachment_decisions()
    {
        var locator = new DingTalkWindowLocator(static () => new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x851),
                Title: "Tool",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: false,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: true,
                Width: 300,
                Height: 450,
                ZOrder: 1,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x852),
                Title: "\u9489\u9489",
                ClassName: "DingTalkMini",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 120,
                Height: 80,
                ZOrder: 2,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x853),
                Title: "\u9489\u9489",
                ClassName: "StandardFrame_DingTalk",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 900,
                Height: 700,
                ZOrder: 3,
                ProcessName: "DingTalk"),
        });

        var diagnostics = new WindowDiagnosticsProvider(locator).GetCandidateDiagnostics(limit: 10);

        Assert.Collection(
            diagnostics.Candidates,
            third =>
            {
                Assert.Equal("0x853", third.Hwnd);
                Assert.Equal(WindowCandidateAttachmentDecision.Selected, third.Decision);
                Assert.Equal(WindowCandidateRejectionReason.None, third.RejectionReason);
                Assert.True(third.IsSelected);
            },
            second =>
            {
                Assert.Equal("0x852", second.Hwnd);
                Assert.Equal(WindowCandidateAttachmentDecision.Rejected, second.Decision);
                Assert.Equal(WindowCandidateRejectionReason.TooSmall, second.RejectionReason);
                Assert.False(second.IsSelected);
            },
            first =>
            {
                Assert.Equal("0x851", first.Hwnd);
                Assert.Equal(WindowCandidateAttachmentDecision.Rejected, first.Decision);
                Assert.Equal(WindowCandidateRejectionReason.ToolWindow, first.RejectionReason);
                Assert.False(first.IsSelected);
            });
    }

    [Fact]
    public void WindowDiagnostics_treats_visible_top_level_ding_chat_window_as_supported()
    {
        var locator = new DingTalkWindowLocator(static () => new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x856),
                Title: "\u9489\u9489",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1280,
                Height: 900,
                ZOrder: 1,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x857),
                Title: "",
                ClassName: "DingChatWnd",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 1095,
                Height: 843,
                ZOrder: 2,
                ProcessName: "DingTalk"),
        });

        var diagnostics = new WindowDiagnosticsProvider(locator).GetCandidateDiagnostics(limit: 10);

        Assert.Equal("0x857", diagnostics.SelectedHwnd);
        var selected = Assert.Single(
            diagnostics.Candidates,
            candidate => candidate.Hwnd == "0x857");
        Assert.Equal(WindowCandidateAttachmentDecision.Selected, selected.Decision);
        Assert.Equal(WindowCandidateRejectionReason.None, selected.RejectionReason);
    }

    [Fact]
    public void WindowDiagnostics_orders_candidate_details_by_actionability()
    {
        var locator = new DingTalkWindowLocator(static () => new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x861),
                Title: "Tool",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: false,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: true,
                Width: 600,
                Height: 600,
                ZOrder: 1,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x862),
                Title: "\u9489\u9489",
                ClassName: "DingTalkMini",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 120,
                Height: 80,
                ZOrder: 2,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x863),
                Title: "preloader",
                ClassName: "pre_loader_host_wnd",
                IsVisible: false,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 170,
                Height: 47,
                ZOrder: 3,
                ProcessName: "DingTalk"),
        });

        var diagnostics = new WindowDiagnosticsProvider(locator).GetCandidateDiagnostics(limit: 3);

        Assert.Equal("0x862", diagnostics.Candidates[0].Hwnd);
        Assert.Equal(WindowCandidateRejectionReason.TooSmall, diagnostics.Candidates[0].RejectionReason);
        Assert.Equal("0x863", diagnostics.Candidates[1].Hwnd);
        Assert.Equal(WindowCandidateRejectionReason.TooSmall, diagnostics.Candidates[1].RejectionReason);
        Assert.Equal("0x861", diagnostics.Candidates[2].Hwnd);
        Assert.Equal(WindowCandidateRejectionReason.ToolWindow, diagnostics.Candidates[2].RejectionReason);
    }

    [Fact]
    public void WindowDiagnostics_counts_rejection_reasons_for_all_candidates()
    {
        var locator = new DingTalkWindowLocator(static () => new[]
        {
            new WindowCandidate(
                Handle: new IntPtr(0x871),
                Title: "Tool A",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: false,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: true,
                Width: 600,
                Height: 600,
                ZOrder: 1,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x872),
                Title: "Tool B",
                ClassName: "Qt51511QWindowIcon",
                IsVisible: false,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: true,
                Width: 500,
                Height: 500,
                ZOrder: 2,
                ProcessName: "DingTalk"),
            new WindowCandidate(
                Handle: new IntPtr(0x873),
                Title: "Tiny",
                ClassName: "DingTalkMini",
                IsVisible: true,
                IsEnabled: true,
                IsTopLevel: true,
                IsToolWindow: false,
                Width: 120,
                Height: 80,
                ZOrder: 3,
                ProcessName: "DingTalk"),
        });

        var diagnostics = new WindowDiagnosticsProvider(locator).GetCandidateDiagnostics(limit: 1);

        Assert.Equal(3, diagnostics.RejectionReasonCounts.Values.Sum());
        Assert.Equal(2, diagnostics.RejectionReasonCounts[WindowCandidateRejectionReason.ToolWindow]);
        Assert.Equal(1, diagnostics.RejectionReasonCounts[WindowCandidateRejectionReason.TooSmall]);
    }

    [Fact]
    public void NativeWindowEmbedder_attach_reparents_as_child_and_fills_host_client_area()
    {
        RunOnStaThread(() =>
        {
            using var host = new System.Windows.Forms.Form
            {
                StartPosition = System.Windows.Forms.FormStartPosition.Manual,
                Location = new System.Drawing.Point(80, 80),
                ClientSize = new System.Drawing.Size(640, 480),
                ShowInTaskbar = false,
                Text = "DingTalk host test shell",
            };
            using var child = new System.Windows.Forms.Form
            {
                StartPosition = System.Windows.Forms.FormStartPosition.Manual,
                Location = new System.Drawing.Point(900, 80),
                ClientSize = new System.Drawing.Size(320, 240),
                ShowInTaskbar = false,
                Text = "DingTalk hosted test child",
            };

            host.Show();
            child.Show();
            System.Windows.Forms.Application.DoEvents();

            var embedder = new NativeWindowEmbedder();
            embedder.Attach(child.Handle, host.Handle, new HostSurfaceBounds(640, 480));
            System.Windows.Forms.Application.DoEvents();

            Assert.Equal(host.Handle, GetParentForTest(child.Handle));

            var style = GetWindowLongPtrForTest(child.Handle, GwlStyleForTest).ToInt64();
            Assert.True((style & WsChildForTest) != 0, "Attached window must use WS_CHILD style.");
            Assert.True((style & WsPopupForTest) == 0, "Attached window must not keep WS_POPUP style.");
            Assert.True((style & WsCaptionForTest) == 0, "Attached window must remove its caption.");
            Assert.True((style & WsThickFrameForTest) == 0, "Attached window must remove resize borders.");

            Assert.True(GetWindowRectForTest(child.Handle, out var childRect));
            var hostClientOrigin = host.PointToScreen(System.Drawing.Point.Empty);
            Assert.Equal(hostClientOrigin.X, childRect.Left);
            Assert.Equal(hostClientOrigin.Y, childRect.Top);
            Assert.Equal(640, childRect.Right - childRect.Left);
            Assert.Equal(480, childRect.Bottom - childRect.Top);

            embedder.Detach();
        });
    }

    [Fact]
    public void NativeWindowEmbedder_attach_restores_previous_child_when_replacing_attachment()
    {
        RunOnStaThread(() =>
        {
            using var host = new System.Windows.Forms.Form
            {
                StartPosition = System.Windows.Forms.FormStartPosition.Manual,
                Location = new System.Drawing.Point(80, 80),
                ClientSize = new System.Drawing.Size(640, 480),
                ShowInTaskbar = false,
                Text = "DingTalk host test shell",
            };
            using var firstChild = new System.Windows.Forms.Form
            {
                StartPosition = System.Windows.Forms.FormStartPosition.Manual,
                Location = new System.Drawing.Point(900, 80),
                ClientSize = new System.Drawing.Size(320, 240),
                ShowInTaskbar = false,
                Text = "DingTalk hosted test child one",
            };
            using var secondChild = new System.Windows.Forms.Form
            {
                StartPosition = System.Windows.Forms.FormStartPosition.Manual,
                Location = new System.Drawing.Point(900, 360),
                ClientSize = new System.Drawing.Size(320, 240),
                ShowInTaskbar = false,
                Text = "DingTalk hosted test child two",
            };

            host.Show();
            firstChild.Show();
            secondChild.Show();
            System.Windows.Forms.Application.DoEvents();

            var firstOriginalStyle = GetWindowLongPtrForTest(firstChild.Handle, GwlStyleForTest).ToInt64();
            var firstOriginalParent = GetParentForTest(firstChild.Handle);

            var embedder = new NativeWindowEmbedder();
            embedder.Attach(firstChild.Handle, host.Handle, new HostSurfaceBounds(640, 480));
            embedder.Attach(secondChild.Handle, host.Handle, new HostSurfaceBounds(640, 480));
            System.Windows.Forms.Application.DoEvents();

            Assert.Equal(firstOriginalParent, GetParentForTest(firstChild.Handle));
            Assert.Equal(firstOriginalStyle, GetWindowLongPtrForTest(firstChild.Handle, GwlStyleForTest).ToInt64());
            Assert.Equal(host.Handle, GetParentForTest(secondChild.Handle));

            embedder.Detach();
        });
    }

    [Fact]
    public void NativeWindowEmbedder_attach_same_child_preserves_original_style_for_detach()
    {
        RunOnStaThread(() =>
        {
            using var host = new System.Windows.Forms.Form
            {
                StartPosition = System.Windows.Forms.FormStartPosition.Manual,
                Location = new System.Drawing.Point(80, 80),
                ClientSize = new System.Drawing.Size(640, 480),
                ShowInTaskbar = false,
                Text = "DingTalk host test shell",
            };
            using var child = new System.Windows.Forms.Form
            {
                StartPosition = System.Windows.Forms.FormStartPosition.Manual,
                Location = new System.Drawing.Point(900, 80),
                ClientSize = new System.Drawing.Size(320, 240),
                ShowInTaskbar = false,
                Text = "DingTalk hosted test child",
            };

            host.Show();
            child.Show();
            System.Windows.Forms.Application.DoEvents();

            var originalStyle = GetWindowLongPtrForTest(child.Handle, GwlStyleForTest).ToInt64();
            var originalParent = GetParentForTest(child.Handle);

            var embedder = new NativeWindowEmbedder();
            embedder.Attach(child.Handle, host.Handle, new HostSurfaceBounds(640, 480));
            embedder.Attach(child.Handle, host.Handle, new HostSurfaceBounds(800, 600));
            embedder.Detach();
            System.Windows.Forms.Application.DoEvents();

            Assert.Equal(originalParent, GetParentForTest(child.Handle));
            Assert.Equal(originalStyle, GetWindowLongPtrForTest(child.Handle, GwlStyleForTest).ToInt64());
        });
    }

    private const int GwlStyleForTest = -16;
    private const long WsCaptionForTest = 0x00C00000L;
    private const long WsChildForTest = 0x40000000L;
    private const long WsPopupForTest = 0x80000000L;
    private const long WsThickFrameForTest = 0x00040000L;

    private static void RunOnStaThread(Action action)
    {
        Exception? failure = null;
        var thread = new Thread(() =>
        {
            try
            {
                action();
            }
            catch (Exception ex)
            {
                failure = ex;
            }
        });
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        Assert.True(thread.Join(TimeSpan.FromSeconds(10)));
        if (failure is not null)
        {
            ExceptionDispatchInfo.Capture(failure).Throw();
        }
    }

    private static IntPtr GetWindowLongPtrForTest(IntPtr handle, int index)
    {
        return IntPtr.Size == 8
            ? GetWindowLongPtr64ForTest(handle, index)
            : new IntPtr(GetWindowLong32ForTest(handle, index));
    }

    [DllImport("user32.dll", EntryPoint = "GetParent", SetLastError = true)]
    private static extern IntPtr GetParentForTest(IntPtr hWnd);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtr", SetLastError = true)]
    private static extern IntPtr GetWindowLongPtr64ForTest(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "GetWindowLong", SetLastError = true)]
    private static extern int GetWindowLong32ForTest(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "GetWindowRect", SetLastError = true)]
    private static extern bool GetWindowRectForTest(IntPtr hWnd, out WindowRectForTest lpRect);

    [StructLayout(LayoutKind.Sequential)]
    private readonly struct WindowRectForTest
    {
        public readonly int Left;
        public readonly int Top;
        public readonly int Right;
        public readonly int Bottom;
    }

    private sealed class FakeWindowEmbedder : IWindowEmbedder
    {
        public EmbeddedWindowState? CurrentState { get; private set; }

        public int AttachCount { get; private set; }

        public int DetachCount { get; private set; }

        public int RestorePreviousAttachmentCount { get; private set; }

        public bool RestorePreviousAttachmentResult { get; init; }

        public bool ThrowOnDetach { get; set; }

        public void Attach(IntPtr childHandle, IntPtr hostHandle, HostSurfaceBounds bounds)
        {
            AttachCount++;
            CurrentState = new EmbeddedWindowState(
                HostHandle: hostHandle,
                ChildHandle: childHandle,
                OriginalParentHandle: IntPtr.Zero,
                Bounds: bounds.Normalize(),
                AttachedAt: DateTimeOffset.UtcNow,
                OriginalStyle: IntPtr.Zero,
                OriginalExStyle: IntPtr.Zero);
        }

        public void Resize(HostSurfaceBounds bounds)
        {
            if (CurrentState is not null)
            {
                CurrentState = CurrentState with { Bounds = bounds.Normalize() };
            }
        }

        public void EnsureAttachment(IntPtr childHandle, IntPtr hostHandle, HostSurfaceBounds bounds)
        {
            if (!IsAttachedTo(childHandle, hostHandle))
            {
                Attach(childHandle, hostHandle, bounds);
                return;
            }

            Resize(bounds);
        }

        public bool IsAttachedTo(IntPtr childHandle, IntPtr hostHandle)
        {
            return CurrentState is not null
                && CurrentState.ChildHandle == childHandle
                && CurrentState.HostHandle == hostHandle;
        }

        public bool TryRestorePreviousAttachment()
        {
            RestorePreviousAttachmentCount++;
            return RestorePreviousAttachmentResult;
        }

        public void Detach()
        {
            DetachCount++;
            if (ThrowOnDetach)
            {
                CurrentState = null;
                throw new InvalidOperationException("detach failed");
            }

            CurrentState = null;
        }
    }
}
