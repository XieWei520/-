using DingTalkWindowsHost.Automation.WindowHost;
using DingTalkWindowsHost.Contracts.Models;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class DingTalkWindowRestorerTests
{
    [Fact]
    public void Restore_returns_no_candidate_when_no_windows_exist()
    {
        var restorer = new DingTalkWindowRestorer(
            new DingTalkWindowLocator(static () => Array.Empty<WindowCandidate>()),
            static _ => true);

        var result = restorer.Restore();

        Assert.Equal(DingTalkWindowRestoreStatus.NoCandidate, result.Status);
        Assert.Equal("", result.TargetHwnd);
    }

    [Fact]
    public void Restore_prefers_non_tool_hidden_or_small_candidate_over_tool_window()
    {
        var restored = new List<IntPtr>();
        var restorer = new DingTalkWindowRestorer(
            new DingTalkWindowLocator(static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x901),
                    Title: "Tool",
                    ClassName: "Qt51511QWindowIcon",
                    IsVisible: false,
                    IsEnabled: true,
                    IsTopLevel: true,
                    IsToolWindow: true,
                    Width: 800,
                    Height: 600,
                    ZOrder: 1,
                    ProcessName: "DingTalk"),
                new WindowCandidate(
                    Handle: new IntPtr(0x902),
                    Title: "DingTalk",
                    ClassName: "Qt51511QWindowIcon",
                    IsVisible: false,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 341,
                    Height: 48,
                    ZOrder: 2,
                    ProcessName: "DingTalk"),
            }),
            handle =>
            {
                restored.Add(handle);
                return true;
            });

        var result = restorer.Restore();

        Assert.Equal(DingTalkWindowRestoreStatus.Restored, result.Status);
        Assert.Equal("0x902", result.TargetHwnd);
        Assert.Equal(new[] { new IntPtr(0x902) }, restored);
    }

    [Fact]
    public void Restore_prefers_visible_main_sized_candidate_over_hidden_small_candidate()
    {
        var restored = new List<IntPtr>();
        var restorer = new DingTalkWindowRestorer(
            new DingTalkWindowLocator(static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x951),
                    Title: "DingTalk",
                    ClassName: "Qt51511QWindowIcon",
                    IsVisible: false,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 341,
                    Height: 48,
                    ZOrder: 0,
                    ProcessName: "DingTalk"),
                new WindowCandidate(
                    Handle: new IntPtr(0x952),
                    Title: "DingTalk",
                    ClassName: "Qt51511QWindowIcon",
                    IsVisible: true,
                    IsEnabled: true,
                    IsTopLevel: true,
                    IsToolWindow: false,
                    Width: 1280,
                    Height: 900,
                    ZOrder: 1,
                    ProcessName: "DingTalk"),
            }),
            handle =>
            {
                restored.Add(handle);
                return true;
            });

        var result = restorer.Restore();

        Assert.Equal(DingTalkWindowRestoreStatus.Restored, result.Status);
        Assert.Equal("0x952", result.TargetHwnd);
        Assert.Equal(new[] { new IntPtr(0x952) }, restored);
    }

    [Fact]
    public void Restore_returns_no_candidate_when_only_visible_small_qt_helper_frame_exists()
    {
        var restored = new List<IntPtr>();
        var restorer = new DingTalkWindowRestorer(
            new DingTalkWindowLocator(static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x953),
                    Title: "DingTalk",
                    ClassName: "Qt51511QWindowIcon",
                    IsVisible: true,
                    IsEnabled: true,
                    IsTopLevel: true,
                    IsToolWindow: false,
                    Width: 218,
                    Height: 247,
                    ZOrder: 0,
                    ProcessName: "DingTalk"),
            }),
            handle =>
            {
                restored.Add(handle);
                return true;
            });

        var result = restorer.Restore();

        Assert.Equal(DingTalkWindowRestoreStatus.NoCandidate, result.Status);
        Assert.Equal("", result.TargetHwnd);
        Assert.Empty(restored);
    }

    [Fact]
    public void Restore_prefers_hidden_main_sized_candidate_over_visible_small_qt_helper_frame()
    {
        var restored = new List<IntPtr>();
        var restorer = new DingTalkWindowRestorer(
            new DingTalkWindowLocator(static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x954),
                    Title: "DingTalk",
                    ClassName: "Qt51511QWindowIcon",
                    IsVisible: true,
                    IsEnabled: true,
                    IsTopLevel: true,
                    IsToolWindow: false,
                    Width: 218,
                    Height: 247,
                    ZOrder: 0,
                    ProcessName: "DingTalk"),
                new WindowCandidate(
                    Handle: new IntPtr(0x955),
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
            }),
            handle =>
            {
                restored.Add(handle);
                return true;
            });

        var result = restorer.Restore();

        Assert.Equal(DingTalkWindowRestoreStatus.Restored, result.Status);
        Assert.Equal("0x955", result.TargetHwnd);
        Assert.Equal(new[] { new IntPtr(0x955) }, restored);
    }

    [Fact]
    public void Restore_rejects_mask_window_when_real_workspace_candidate_exists()
    {
        var restored = new List<IntPtr>();
        var restorer = new DingTalkWindowRestorer(
            new DingTalkWindowLocator(static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x931),
                    Title: string.Empty,
                    ClassName: "UIMaskWnd",
                    IsVisible: false,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 1280,
                    Height: 800,
                    ZOrder: 0,
                    ProcessName: "DingTalk"),
                new WindowCandidate(
                    Handle: new IntPtr(0x932),
                    Title: "DingTalk",
                    ClassName: "Qt51511QWindowIcon",
                    IsVisible: false,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 1024,
                    Height: 640,
                    ZOrder: 1,
                    ProcessName: "DingTalk"),
            }),
            handle =>
            {
                restored.Add(handle);
                return true;
            });

        var result = restorer.Restore();

        Assert.Equal(DingTalkWindowRestoreStatus.Restored, result.Status);
        Assert.Equal("0x932", result.TargetHwnd);
        Assert.Equal(new[] { new IntPtr(0x932) }, restored);
    }

    [Fact]
    public void Restore_rejects_chromium_render_child_when_qt_workspace_exists()
    {
        var restored = new List<IntPtr>();
        var restorer = new DingTalkWindowRestorer(
            new DingTalkWindowLocator(static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x941),
                    Title: "Chrome Legacy Window",
                    ClassName: "Chrome_RenderWidgetHostHWND",
                    IsVisible: false,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 1025,
                    Height: 714,
                    ZOrder: 0,
                    ProcessName: "DingTalk"),
                new WindowCandidate(
                    Handle: new IntPtr(0x942),
                    Title: "DingTalk",
                    ClassName: "Qt51511QWindowIcon",
                    IsVisible: false,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 1024,
                    Height: 640,
                    ZOrder: 1,
                    ProcessName: "DingTalk"),
            }),
            handle =>
            {
                restored.Add(handle);
                return true;
            });

        var result = restorer.Restore();

        Assert.Equal(DingTalkWindowRestoreStatus.Restored, result.Status);
        Assert.Equal("0x942", result.TargetHwnd);
        Assert.Equal(new[] { new IntPtr(0x942) }, restored);
    }

    [Fact]
    public void Restore_rejects_transient_role_popup_when_main_frame_exists()
    {
        var restored = new List<IntPtr>();
        var restorer = new DingTalkWindowRestorer(
            new DingTalkWindowLocator(static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x961),
                    Title: "Form",
                    ClassName: "DTIMChatAtRoleWndView",
                    IsVisible: true,
                    IsEnabled: true,
                    IsTopLevel: true,
                    IsToolWindow: false,
                    Width: 818,
                    Height: 647,
                    ZOrder: 0,
                    ProcessName: "DingTalk"),
                new WindowCandidate(
                    Handle: new IntPtr(0x962),
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
            }),
            handle =>
            {
                restored.Add(handle);
                return true;
            });

        var result = restorer.Restore();

        Assert.Equal(DingTalkWindowRestoreStatus.Restored, result.Status);
        Assert.Equal("0x962", result.TargetHwnd);
        Assert.Equal(new[] { new IntPtr(0x962) }, restored);
    }

    [Fact]
    public void Restore_returns_no_candidate_when_only_transient_overlay_exists()
    {
        var restorer = new DingTalkWindowRestorer(
            new DingTalkWindowLocator(static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x963),
                    Title: "Form",
                    ClassName: "DTIMChatAtRoleWndView",
                    IsVisible: true,
                    IsEnabled: true,
                    IsTopLevel: true,
                    IsToolWindow: false,
                    Width: 818,
                    Height: 647,
                    ZOrder: 0,
                    ProcessName: "DingTalk"),
            }),
            static _ => true);

        var result = restorer.Restore();

        Assert.Equal(DingTalkWindowRestoreStatus.NoCandidate, result.Status);
        Assert.Equal("", result.TargetHwnd);
    }

    [Fact]
    public void Restore_reports_failed_when_native_restore_fails()
    {
        var restorer = new DingTalkWindowRestorer(
            new DingTalkWindowLocator(static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x911),
                    Title: "DingTalk",
                    ClassName: "Qt51511QWindowIcon",
                    IsVisible: false,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 341,
                    Height: 48,
                    ZOrder: 1,
                    ProcessName: "DingTalk"),
            }),
            static _ => false);

        var result = restorer.Restore();

        Assert.Equal(DingTalkWindowRestoreStatus.Failed, result.Status);
        Assert.Equal("0x911", result.TargetHwnd);
    }

    [Fact]
    public void Restore_reports_failed_when_native_restore_throws()
    {
        var restorer = new DingTalkWindowRestorer(
            new DingTalkWindowLocator(static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x922),
                    Title: "DingTalk",
                    ClassName: "Qt51511QWindowIcon",
                    IsVisible: false,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 341,
                    Height: 48,
                    ZOrder: 1,
                    ProcessName: "DingTalk"),
            }),
            static _ => throw new InvalidOperationException("native restore failed"));

        var result = restorer.Restore();

        Assert.Equal(DingTalkWindowRestoreStatus.Failed, result.Status);
        Assert.Equal("0x922", result.TargetHwnd);
        Assert.Contains("native restore failed", result.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Restore_reports_failed_when_candidate_lookup_throws()
    {
        var restorer = new DingTalkWindowRestorer(
            new DingTalkWindowLocator(static () => throw new InvalidOperationException("window lookup failed")),
            static _ => true);

        var result = restorer.Restore();

        Assert.Equal(DingTalkWindowRestoreStatus.Failed, result.Status);
        Assert.Equal("", result.TargetHwnd);
        Assert.Contains("window lookup failed", result.Message, StringComparison.Ordinal);
    }
}
