using System.Text.Json;
using DingTalkWindowsHost.Automation.Capture;
using DingTalkWindowsHost.Automation.WindowHost;
using DingTalkWindowsHost.Contracts.Models;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class UiaTextCandidateDiagnosticsProviderTests
{
    [Fact]
    public void GetDiagnostics_returns_only_redacted_text_metadata()
    {
        var provider = new UiaTextCandidateDiagnosticsProvider(
            candidateProvider: static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x5678),
                    Title: "Private group",
                    ClassName: "DingChatWnd",
                    IsVisible: true,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 1024,
                    Height: 713,
                    ZOrder: 1,
                    ProcessName: "DingTalk"),
            },
            descendantCandidateProvider: static _ => Array.Empty<WindowCandidate>(),
            hostedWindowHandle: static () => IntPtr.Zero,
            rootNodeProvider: static (_, _) => new[]
            {
                new UiaNode(
                    AutomationId: "messageBody",
                    Name: "sensitive message",
                    ControlType: "Text",
                    ClassName: "QLabel"),
                new UiaNode(
                    AutomationId: "sendButton",
                    Name: "Send",
                    ControlType: "Button",
                    ClassName: "QPushButton"),
            },
            messageSurfaceNodeProvider: static (_, _) => Array.Empty<UiaNode>());

        var result = provider.GetDiagnostics(
            candidateLimit: 4,
            snapshotLimit: 10,
            messageSurfaceLimit: 10,
            minimumTextLength: 2);
        var json = JsonSerializer.Serialize(result);

        Assert.Equal(StructuredSourceStatus.NeedsProbe, result.Status);
        var window = Assert.Single(result.Windows);
        Assert.Equal(2, window.TextCandidateCount);
        Assert.Equal(1, window.PotentialMessageTextCount);
        var textCandidate = Assert.Single(window.TextCandidates, static item => item.IsPotentialMessageText);
        Assert.Equal(17, textCandidate.NameLength);
        Assert.Equal(64, textCandidate.NameHash.Length);
        Assert.Equal(64, textCandidate.AutomationIdHash.Length);
        Assert.DoesNotContain("sensitive message", json, StringComparison.Ordinal);
        Assert.DoesNotContain("messageBody", json, StringComparison.Ordinal);
        Assert.DoesNotContain("Private group", json, StringComparison.Ordinal);
    }

    [Fact]
    public void GetDiagnostics_marks_unavailable_when_no_text_like_nodes_are_exposed()
    {
        var provider = new UiaTextCandidateDiagnosticsProvider(
            candidateProvider: static () => new[]
            {
                new WindowCandidate(
                    Handle: new IntPtr(0x5678),
                    Title: string.Empty,
                    ClassName: "DingChatWnd",
                    IsVisible: true,
                    IsEnabled: true,
                    IsTopLevel: false,
                    IsToolWindow: false,
                    Width: 1024,
                    Height: 713,
                    ZOrder: 1,
                    ProcessName: "DingTalk"),
            },
            descendantCandidateProvider: static _ => Array.Empty<WindowCandidate>(),
            hostedWindowHandle: static () => IntPtr.Zero,
            rootNodeProvider: static (_, _) => Array.Empty<UiaNode>(),
            messageSurfaceNodeProvider: static (_, _) => Array.Empty<UiaNode>());

        var result = provider.GetDiagnostics(
            candidateLimit: 4,
            snapshotLimit: 10,
            messageSurfaceLimit: 10,
            minimumTextLength: 2);

        Assert.Equal(StructuredSourceStatus.Unavailable, result.Status);
        Assert.Contains("did not expose", result.Recommendation, StringComparison.OrdinalIgnoreCase);
    }
}
