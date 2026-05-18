using System.Net;
using System.Net.Http.Json;
using System.Runtime.InteropServices;
using System.Text.Json;
using DingTalkWindowsHost.Api;
using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Contracts.Services;
using DingTalkWindowsHost.Storage.Db;
using DingTalkWindowsHost.Storage.Repositories;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class LoopbackApiTests
{
    [Fact]
    public async Task Status_requires_local_token_header()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;

        var response = await client.GetAsync("/status");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task EventsRecent_returns_persisted_events_with_token()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var repository = fixture.Host.Services.GetRequiredService<RawEventsRepository>();
        await repository.UpsertAsync(CreateEvent(), CancellationToken.None);

        var events = await client.GetFromJsonAsync<IReadOnlyList<DingTalkObservedEvent>>("/events/recent?limit=5");

        var only = Assert.Single(events!);
        Assert.Equal("evt-1", only.EventId);
        Assert.Equal("hello", only.Text);
    }

    [Fact]
    public async Task EventsForwardableRecent_excludes_visual_change_diagnostics_with_token()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var repository = fixture.Host.Services.GetRequiredService<RawEventsRepository>();
        await repository.UpsertAsync(
            CreateEvent(
                "evt-visual",
                "Chat area visual change abc123",
                CaptureSource.ChatAreaScreenshot,
                senderName: "VisualHash"),
            CancellationToken.None);
        await repository.UpsertAsync(
            CreateEvent("evt-text", "hello", CaptureSource.UiaText),
            CancellationToken.None);
        await repository.UpsertAsync(
            CreateEvent("evt-source-diagnostic", "navigation text", CaptureSource.UiaText, sourceConversationId: "source:alpha"),
            CancellationToken.None);

        var events = await client.GetFromJsonAsync<IReadOnlyList<DingTalkObservedEvent>>(
            "/events/forwardable-recent?limit=5");

        var only = Assert.Single(events!);
        Assert.Equal("evt-text", only.EventId);
        Assert.Equal("hello", only.Text);
    }

    [Fact]
    public async Task ControlStart_sets_capture_running()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var response = await client.PostAsync("/control/start", null);
        var status = await client.GetFromJsonAsync<LoopbackStatusDto>("/status");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.True(status!.CaptureRunning);
    }

    [Fact]
    public async Task ControlLaunchDingTalk_returns_launcher_result_with_token()
    {
        await using var fixture = await CreateFixtureAsync(dingTalkLauncher: new StaticDingTalkLauncher());
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var response = await client.PostAsync("/control/launch-dingtalk", null);
        var result = await response.Content.ReadFromJsonAsync<DingTalkLaunchResult>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(DingTalkLaunchStatus.Started, result!.Status);
    }

    [Fact]
    public async Task ControlRestartDingTalk_returns_launcher_result_with_token()
    {
        await using var fixture = await CreateFixtureAsync(dingTalkLauncher: new StaticDingTalkLauncher());
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var response = await client.PostAsync("/control/restart-dingtalk", null);
        var result = await response.Content.ReadFromJsonAsync<DingTalkLaunchResult>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(DingTalkLaunchStatus.Started, result!.Status);
        Assert.Contains("restarted", result.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ControlRestoreDingTalkWindow_returns_restore_result_with_token()
    {
        await using var fixture = await CreateFixtureAsync(windowRestorer: new StaticDingTalkWindowRestorer());
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var response = await client.PostAsync("/control/restore-dingtalk-window", null);
        var result = await response.Content.ReadFromJsonAsync<DingTalkWindowRestoreResult>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(DingTalkWindowRestoreStatus.Restored, result!.Status);
        Assert.Equal("0x902", result.TargetHwnd);
    }

    [Fact]
    public async Task ControlRestoreDingTalkWindow_returns_failed_result_when_restorer_throws()
    {
        await using var fixture = await CreateFixtureAsync(windowRestorer: new ThrowingDingTalkWindowRestorer());
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var response = await client.PostAsync("/control/restore-dingtalk-window", null);
        var result = await response.Content.ReadFromJsonAsync<DingTalkWindowRestoreResult>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(DingTalkWindowRestoreStatus.Failed, result!.Status);
        Assert.Equal("", result.TargetHwnd);
        Assert.Contains("restore endpoint failed", result.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task ControlOpenMessages_invokes_message_navigator_with_explicit_hwnd()
    {
        var navigator = new RecordingDingTalkMessageNavigator();
        await using var fixture = await CreateFixtureAsync(messageNavigator: navigator);
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var response = await client.PostAsync("/control/open-messages?hwnd=0x2468", null);
        var result = await response.Content.ReadFromJsonAsync<DingTalkNavigationResult>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(new IntPtr(0x2468), navigator.LastWindowHandle);
        Assert.Equal(DingTalkNavigationStatus.Activated, result!.Status);
        Assert.Equal("navigator_view.im_im", result.TargetAutomationId);
    }

    [Fact]
    public async Task ControlOpenMessages_returns_failed_result_when_navigator_throws()
    {
        await using var fixture = await CreateFixtureAsync(messageNavigator: new ThrowingDingTalkMessageNavigator());
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var response = await client.PostAsync("/control/open-messages?hwnd=0x2468", null);
        var result = await response.Content.ReadFromJsonAsync<DingTalkNavigationResult>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(DingTalkNavigationStatus.Failed, result!.Status);
        Assert.Equal("0x2468", result.TargetHwnd);
        Assert.Equal("navigator_view.im_im", result.TargetAutomationId);
        Assert.Contains("open messages endpoint failed", result.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task ControlOpenMessages_includes_exception_type_when_exception_message_is_empty()
    {
        await using var fixture = await CreateFixtureAsync(
            messageNavigator: new EmptyMessageThrowingDingTalkMessageNavigator());
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var response = await client.PostAsync("/control/open-messages?hwnd=0x2468", null);
        var result = await response.Content.ReadFromJsonAsync<DingTalkNavigationResult>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(DingTalkNavigationStatus.Failed, result!.Status);
        Assert.Contains("ExternalException", result.Message, StringComparison.Ordinal);
        Assert.Contains("HResult=", result.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task ControlCloseSearchOverlay_invokes_message_navigator_with_runtime_hwnd()
    {
        var navigator = new RecordingDingTalkMessageNavigator();
        await using var fixture = await CreateFixtureAsync(messageNavigator: navigator);
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var response = await client.PostAsync("/control/close-search-overlay?hwnd=0x2468", null);
        var result = await response.Content.ReadFromJsonAsync<DingTalkNavigationResult>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(new IntPtr(0x2468), navigator.LastWindowHandle);
        Assert.Equal(DingTalkNavigationStatus.Closed, result!.Status);
        Assert.Equal("advancedSearch", result.TargetAutomationId);
    }

    [Fact]
    public async Task ControlCloseSearchOverlay_returns_failed_result_when_navigator_throws()
    {
        await using var fixture = await CreateFixtureAsync(messageNavigator: new ThrowingDingTalkMessageNavigator());
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var response = await client.PostAsync("/control/close-search-overlay?hwnd=0x2468", null);
        var result = await response.Content.ReadFromJsonAsync<DingTalkNavigationResult>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(DingTalkNavigationStatus.Failed, result!.Status);
        Assert.Equal("0x2468", result.TargetHwnd);
        Assert.Equal("advancedSearch", result.TargetAutomationId);
        Assert.Contains("close search overlay endpoint failed", result.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task DiagnosticsLauncher_returns_launcher_readiness_with_token()
    {
        await using var fixture = await CreateFixtureAsync(dingTalkLauncher: new StaticDingTalkLauncher());
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var diagnostics = await client.GetFromJsonAsync<DingTalkLauncherDiagnosticsResult>(
            "/diagnostics/launcher");

        Assert.NotNull(diagnostics);
        Assert.Equal(DingTalkLauncherReadiness.Ready, diagnostics!.Readiness);
        Assert.True(diagnostics.IsConfigured);
    }

    [Fact]
    public async Task DiagnosticsUiaSnapshot_returns_node_summary_with_token()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var summary = await client.GetFromJsonAsync<IReadOnlyList<string>>("/diagnostics/uia-snapshot?limit=5");

        var only = Assert.Single(summary!);
        Assert.Equal("node-summary", only);
    }

    [Fact]
    public async Task DiagnosticsUiaSnapshot_uses_explicit_hwnd_when_provided()
    {
        var snapshotProvider = new RecordingUiaSnapshotProvider();
        await using var fixture = await CreateFixtureAsync(snapshotProvider);
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        await client.GetFromJsonAsync<IReadOnlyList<string>>("/diagnostics/uia-snapshot?hwnd=0x1234&limit=5");

        Assert.Equal(new IntPtr(0x1234), snapshotProvider.LastWindowHandle);
    }

    [Fact]
    public async Task DiagnosticsUiaSnapshot_returns_error_summary_when_uia_probe_fails()
    {
        await using var fixture = await CreateFixtureAsync(snapshotProvider: new ThrowingUiaSnapshotProvider());
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var summary = await client.GetFromJsonAsync<IReadOnlyList<string>>("/diagnostics/uia-snapshot?limit=5");

        var only = Assert.Single(summary!);
        Assert.Contains("uia-snapshot-error", only, StringComparison.Ordinal);
        Assert.Contains("InvalidOperationException", only, StringComparison.Ordinal);
    }

    [Fact]
    public async Task DiagnosticsUiaMessageSurface_returns_focused_rawview_summary_with_token()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var summary = await client.GetFromJsonAsync<IReadOnlyList<string>>(
            "/diagnostics/uia-message-surface?limit=5");

        var only = Assert.Single(summary!);
        Assert.Equal("message-surface-node", only);
    }

    [Fact]
    public async Task DiagnosticsUiaMessageSurface_uses_explicit_hwnd_when_provided()
    {
        var snapshotProvider = new RecordingUiaSnapshotProvider();
        await using var fixture = await CreateFixtureAsync(snapshotProvider);
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        await client.GetFromJsonAsync<IReadOnlyList<string>>(
            "/diagnostics/uia-message-surface?hwnd=0x1234&limit=5");

        Assert.Equal(new IntPtr(0x1234), snapshotProvider.LastMessageSurfaceWindowHandle);
    }

    [Fact]
    public async Task DiagnosticsUiaMessageSurface_returns_error_summary_when_uia_probe_fails()
    {
        await using var fixture = await CreateFixtureAsync(snapshotProvider: new ThrowingUiaSnapshotProvider());
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var summary = await client.GetFromJsonAsync<IReadOnlyList<string>>(
            "/diagnostics/uia-message-surface?limit=5");

        var only = Assert.Single(summary!);
        Assert.Contains("uia-message-surface-error", only, StringComparison.Ordinal);
        Assert.Contains("InvalidOperationException", only, StringComparison.Ordinal);
    }

    [Fact]
    public async Task DiagnosticsWindowCandidates_returns_candidate_summary_with_token()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var summary = await client.GetFromJsonAsync<IReadOnlyList<string>>("/diagnostics/window-candidates?limit=5");

        var only = Assert.Single(summary!);
        Assert.Equal("window-candidate", only);
    }

    [Fact]
    public async Task DiagnosticsWindowState_returns_typed_window_diagnostics_with_token()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var diagnostics = await client.GetFromJsonAsync<WindowCandidateDiagnosticsResult>(
            "/diagnostics/window-state?limit=5");

        Assert.NotNull(diagnostics);
        Assert.Equal(WindowCandidateHealth.Ready, diagnostics!.Health);
        Assert.Equal("0x1234", diagnostics.SelectedHwnd);
        Assert.Contains("window-candidate", diagnostics.RawSummaries);
        var candidate = Assert.Single(diagnostics.Candidates);
        Assert.Equal(WindowCandidateAttachmentDecision.Selected, candidate.Decision);
        Assert.Equal(WindowCandidateRejectionReason.None, candidate.RejectionReason);
        Assert.Equal(1, diagnostics.RejectionReasonCounts[WindowCandidateRejectionReason.None]);
    }

    [Fact]
    public async Task DiagnosticsWindowState_serializes_health_as_string_for_operator_scripts()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var json = await client.GetStringAsync("/diagnostics/window-state?limit=5");
        using var document = JsonDocument.Parse(json);

        Assert.Equal("Ready", document.RootElement.GetProperty("health").GetString());
    }

    [Fact]
    public async Task DiagnosticsUiaCandidates_returns_candidate_probe_results_with_token()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var result = await client.GetFromJsonAsync<UiaCandidateDiagnosticsResult>(
            "/diagnostics/uia-candidates?limit=4&snapshotLimit=3&conversationLimit=2");

        Assert.NotNull(result);
        Assert.Equal("0x1234", result!.HostedHwnd);
        var probe = Assert.Single(result.Probes);
        Assert.Equal("0x5678", probe.Hwnd);
        Assert.Equal(ConversationReadiness.NoConversationList, probe.Readiness);
        Assert.Equal("candidate-node", Assert.Single(probe.NodeSummary));
    }

    [Fact]
    public async Task DiagnosticsUiaTextCandidates_returns_redacted_text_metadata_with_token()
    {
        await using var fixture = await CreateFixtureAsync(
            uiaTextCandidateDiagnosticsProvider: new StaticUiaTextCandidateDiagnosticsProvider());
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var json = await client.GetStringAsync(
            "/diagnostics/uia-text-candidates?limit=4&snapshotLimit=3&messageSurfaceLimit=2");
        var result = JsonSerializer.Deserialize<UiaTextCandidateDiagnosticsResult>(
            json,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

        Assert.NotNull(result);
        Assert.Equal(StructuredSourceStatus.NeedsProbe, result!.Status);
        var window = Assert.Single(result.Windows);
        var candidate = Assert.Single(window.TextCandidates);
        Assert.Equal(17, candidate.NameLength);
        Assert.Equal(64, candidate.NameHash.Length);
        Assert.DoesNotContain("sensitive message", json, StringComparison.Ordinal);
        Assert.DoesNotContain("messageBody", json, StringComparison.Ordinal);
    }

    [Fact]
    public async Task DiagnosticsUiaTextCandidates_requires_local_token_header()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;

        var response = await client.GetAsync("/diagnostics/uia-text-candidates");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task DiagnosticsClipboardProbe_returns_redacted_probe_metadata_with_token()
    {
        var clipboardProbe = new RecordingClipboardMessageProbe();
        await using var fixture = await CreateFixtureAsync(clipboardMessageProbe: clipboardProbe);
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var result = await client.PostAsync("/diagnostics/clipboard-probe?hwnd=0x1234", null);
        var diagnostics = await result.Content.ReadFromJsonAsync<ClipboardMessageProbeDiagnosticsResult>();

        Assert.Equal(HttpStatusCode.OK, result.StatusCode);
        Assert.Equal(new IntPtr(0x1234), clipboardProbe.LastWindowHandle);
        Assert.Equal("0x1234", diagnostics!.TargetHwnd);
        Assert.Equal("Extracted", diagnostics.Status);
        Assert.Equal(16, diagnostics.ExtractedTextLength);
        Assert.Equal("abc123", diagnostics.ExtractedTextHash);
    }

    [Fact]
    public async Task DiagnosticsClipboardProbe_requires_local_token_header()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;

        var response = await client.PostAsync("/diagnostics/clipboard-probe", null);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task ControlProbeLatest_stores_clipboard_message_as_forwardable_event()
    {
        var clipboardProbe = new RecordingClipboardMessageProbe();
        await using var fixture = await CreateFixtureAsync(clipboardMessageProbe: clipboardProbe);
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var response = await client.PostAsync("/control/probe-latest?hwnd=0x1234", null);
        var result = await response.Content.ReadFromJsonAsync<LatestMessageProbeResult>();
        var events = await client.GetFromJsonAsync<IReadOnlyList<DingTalkObservedEvent>>(
            "/events/forwardable-recent?limit=5");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(new IntPtr(0x1234), clipboardProbe.LastWindowHandle);
        Assert.Equal("Stored", result!.Status);
        Assert.Equal("0x1234", result.TargetHwnd);
        Assert.Equal(16, result.TextLength);
        var only = Assert.Single(events!);
        Assert.Equal(result.EventId, only.EventId);
        Assert.Equal("redacted message", only.Text);
        Assert.Equal("windows:clipboard-active", only.SourceConversationId);
    }

    [Fact]
    public async Task ControlProbeLatest_stores_coordinated_latest_message_before_clipboard_fallback()
    {
        var clipboardProbe = new RecordingClipboardMessageProbe();
        await using var fixture = await CreateFixtureAsync(
            clipboardMessageProbe: clipboardProbe,
            latestMessageProbe: new StaticLatestMessageProbe());
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var response = await client.PostAsync("/control/probe-latest?hwnd=0x1234", null);
        var result = await response.Content.ReadFromJsonAsync<LatestMessageProbeResult>();
        var events = await client.GetFromJsonAsync<IReadOnlyList<DingTalkObservedEvent>>(
            "/events/forwardable-recent?limit=5");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(IntPtr.Zero, clipboardProbe.LastWindowHandle);
        Assert.Equal("Stored", result!.Status);
        Assert.Equal("0x1234", result.TargetHwnd);
        var only = Assert.Single(events!);
        Assert.Equal(result.EventId, only.EventId);
        Assert.Equal("coordinated latest", only.Text);
        Assert.Equal(only.Text.Length, result.TextLength);
        Assert.Equal("windows:coordinated", only.SourceConversationId);
    }

    [Fact]
    public async Task ControlProbeLatest_requires_local_token_header()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;

        var response = await client.PostAsync("/control/probe-latest", null);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task DiagnosticsScreenshot_returns_screenshot_result_with_token()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var result = await client.PostAsync("/diagnostics/screenshot?hwnd=0x1234", null);
        var screenshot = await result.Content.ReadFromJsonAsync<WindowScreenshotResult>();

        Assert.Equal(HttpStatusCode.OK, result.StatusCode);
        Assert.Equal("abc123", screenshot!.Sha256);
    }

    [Fact]
    public async Task DiagnosticsChatScreenshot_returns_cropped_chat_area_result_with_token()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var result = await client.PostAsync("/diagnostics/chat-screenshot?hwnd=0x1234", null);
        var screenshot = await result.Content.ReadFromJsonAsync<WindowScreenshotResult>();

        Assert.Equal(HttpStatusCode.OK, result.StatusCode);
        Assert.Equal("abc123", screenshot!.Sha256);
    }

    [Fact]
    public async Task DiagnosticsConversations_returns_uia_conversation_diagnostics_with_token()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var result = await client.GetFromJsonAsync<UiaConversationDiagnosticsResult>(
            "/diagnostics/conversations?limit=5");

        Assert.NotNull(result);
        var conversation = Assert.Single(result!.Conversations);
        Assert.Equal("Alpha Group", conversation.Name);
        var dialog = Assert.Single(result.BlockingDialogs);
        Assert.Equal("MsgBox", dialog.ClassName);
    }

    [Fact]
    public async Task DiagnosticsConversations_persists_trigger_snapshot_when_conversation_list_is_visible()
    {
        await using var fixture = await CreateFixtureAsync(
            conversationDiagnosticsProvider: new ConversationOnlyUiaConversationDiagnosticsProvider());
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        await client.GetFromJsonAsync<UiaConversationDiagnosticsResult>(
            "/diagnostics/conversations?limit=5");
        var snapshots = await client.GetFromJsonAsync<IReadOnlyList<ConversationTriggerSnapshot>>(
            "/conversation-triggers/recent?limit=5");

        var only = Assert.Single(snapshots!);
        Assert.Equal(ConversationReadiness.ConversationListVisible, only.Readiness);
        Assert.Equal(2, only.ConversationCount);
        Assert.Equal(string.Empty, only.SelectedConversationName);
    }

    [Fact]
    public async Task DiagnosticsConversations_returns_degraded_result_when_uia_probe_fails()
    {
        await using var fixture = await CreateFixtureAsync(
            conversationDiagnosticsProvider: new ThrowingUiaConversationDiagnosticsProvider(
                new InvalidOperationException("conversation probe failed")));
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var result = await client.GetFromJsonAsync<UiaConversationDiagnosticsResult>(
            "/diagnostics/conversations?limit=5");

        Assert.NotNull(result);
        Assert.Empty(result!.Conversations);
        Assert.Empty(result.BlockingDialogs);
        Assert.Contains("conversation-diagnostics-error", result.Recommendation, StringComparison.Ordinal);
    }

    [Fact]
    public async Task DiagnosticsConversations_returns_degraded_result_when_uia_probe_throws_unexpected_exception()
    {
        await using var fixture = await CreateFixtureAsync(
            conversationDiagnosticsProvider: new ThrowingUiaConversationDiagnosticsProvider(
                new NotSupportedException("unexpected uia failure")));
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var response = await client.GetAsync("/diagnostics/conversations?limit=5");
        var result = await response.Content.ReadFromJsonAsync<UiaConversationDiagnosticsResult>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(result);
        Assert.Empty(result!.Conversations);
        Assert.Empty(result.BlockingDialogs);
        Assert.Contains("NotSupportedException", result.Recommendation, StringComparison.Ordinal);
        Assert.Contains("unexpected uia failure", result.Recommendation, StringComparison.Ordinal);
    }

    [Fact]
    public async Task ConversationTriggersRecent_returns_persisted_trigger_snapshots_with_token()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");
        var repository = fixture.Host.Services.GetRequiredService<ConversationTriggerSnapshotsRepository>();
        await repository.AddIfChangedAsync(new UiaConversationDiagnosticsResult(
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
            Conversations: new[]
            {
                new UiaConversationItem(
                    AutomationId: "conv-alpha",
                    Name: "Alpha Group",
                    IsSelected: true,
                    HasUnreadHint: true),
            },
            BlockingDialogs: Array.Empty<UiaBlockingDialog>(),
            Recommendation: "Use conversation list changes as triggers."), CancellationToken.None);

        var snapshots = await client.GetFromJsonAsync<IReadOnlyList<ConversationTriggerSnapshot>>(
            "/conversation-triggers/recent?limit=5");

        var only = Assert.Single(snapshots!);
        Assert.Equal("Alpha Group", only.SelectedConversationName);
        Assert.Equal(1, only.UnreadCount);
        Assert.Equal(ConversationReadiness.Ready, only.Readiness);
    }

    [Fact]
    public async Task DiagnosticsStructuredSources_requires_local_token_header()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;

        var response = await client.GetAsync("/diagnostics/structured-sources");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task DiagnosticsStructuredSources_returns_structured_source_probe_with_token()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var result = await client.GetFromJsonAsync<StructuredSourceProbeResult>(
            "/diagnostics/structured-sources");

        Assert.NotNull(result);
        Assert.Contains(
            result!.Signals,
            signal => signal.Kind == StructuredSourceKind.EmbeddedChromium
                && signal.Status == StructuredSourceStatus.Candidate);
        Assert.Contains("DevTools", result.Recommendation, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task DiagnosticsDevToolsTargets_returns_target_metadata_with_token()
    {
        await using var fixture = await CreateFixtureAsync(
            devToolsTargetDiagnosticsProvider: new StaticDevToolsTargetDiagnosticsProvider());
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var result = await client.GetFromJsonAsync<DevToolsTargetDiagnosticsResult>(
            "/diagnostics/devtools-targets");

        Assert.NotNull(result);
        Assert.Equal(StructuredSourceStatus.Candidate, result!.Status);
        Assert.Equal(9222, result.Port);
        var target = Assert.Single(result.Targets);
        Assert.Equal("page", target.Type);
    }

    [Fact]
    public async Task DiagnosticsLocalStructuredSources_requires_local_token_header()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;

        var response = await client.GetAsync("/diagnostics/local-structured-sources");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task DiagnosticsLocalStructuredSources_returns_candidate_metadata_with_token()
    {
        await using var fixture = await CreateFixtureAsync(
            localStructuredSourceDiagnosticsProvider: new StaticLocalStructuredSourceDiagnosticsProvider());
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var result = await client.GetFromJsonAsync<LocalStructuredSourceDiagnosticsResult>(
            "/diagnostics/local-structured-sources?limit=5");

        Assert.NotNull(result);
        Assert.Equal(StructuredSourceStatus.NeedsManualApproval, result!.Status);
        var candidate = Assert.Single(result.Candidates);
        Assert.Equal(LocalStructuredSourceCandidateKind.SqliteDatabase, candidate.Kind);
        Assert.Equal("%LOCALAPPDATA%\\DingTalk\\message.sqlite", candidate.PathHint);
    }

    [Fact]
    public async Task DiagnosticsLocalStructuredSourceInspection_requires_local_token_header()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;

        var response = await client.GetAsync("/diagnostics/local-structured-source-inspection");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task DiagnosticsLocalStructuredSourceInspection_returns_schema_metadata_with_token()
    {
        await using var fixture = await CreateFixtureAsync(
            localStructuredSourceDiagnosticsProvider: new StaticLocalStructuredSourceDiagnosticsProvider());
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var result = await client.GetFromJsonAsync<LocalStructuredSourceInspectionDiagnosticsResult>(
            "/diagnostics/local-structured-source-inspection?limit=5&itemLimit=10");

        Assert.NotNull(result);
        Assert.Equal(StructuredSourceStatus.NeedsManualApproval, result!.Status);
        var inspection = Assert.Single(result.Inspections);
        Assert.Equal(LocalStructuredSourceInspectionStatus.Inspected, inspection.Status);
        Assert.Equal(LocalStructuredSourceStructureKind.SqliteTable, Assert.Single(inspection.StructureItems).Kind);
    }

    [Fact]
    public async Task DiagnosticsLocalStructuredContentShape_requires_local_token_header()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;

        var response = await client.GetAsync("/diagnostics/local-structured-content-shape");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task DiagnosticsLocalStructuredContentShape_returns_safe_shape_metadata_with_token()
    {
        await using var fixture = await CreateFixtureAsync(
            localStructuredSourceDiagnosticsProvider: new StaticLocalStructuredSourceDiagnosticsProvider());
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var result = await client.GetFromJsonAsync<LocalStructuredContentShapeDiagnosticsResult>(
            "/diagnostics/local-structured-content-shape?limit=5&itemLimit=10&sampleLimit=3");

        Assert.NotNull(result);
        Assert.Equal(StructuredSourceStatus.NeedsManualApproval, result!.Status);
        var shape = Assert.Single(result.Shapes);
        Assert.Equal(LocalStructuredContentShapeStatus.Candidate, shape.Status);
        var table = Assert.Single(shape.Tables);
        Assert.Equal("messages", table.Name);
        Assert.Contains(table.Fields, field => field.Role == LocalStructuredContentFieldRole.Text);
    }

    [Fact]
    public async Task DiagnosticsLocalStructuredSourceChanges_requires_local_token_header()
    {
        await using var fixture = await CreateFixtureAsync();
        using var client = fixture.Client;

        var response = await client.GetAsync("/diagnostics/local-structured-source-changes");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task DiagnosticsLocalStructuredSourceChanges_returns_safe_change_metadata_with_token()
    {
        await using var fixture = await CreateFixtureAsync(
            localStructuredSourceDiagnosticsProvider: new StaticLocalStructuredSourceDiagnosticsProvider());
        using var client = fixture.Client;
        client.DefaultRequestHeaders.Add(LoopbackApiOptions.TokenHeaderName, "test-token");

        var result = await client.GetFromJsonAsync<LocalStructuredSourceChangeDiagnosticsResult>(
            "/diagnostics/local-structured-source-changes?limit=5&resetBaseline=true");

        Assert.NotNull(result);
        Assert.Equal(StructuredSourceStatus.NeedsManualApproval, result!.Status);
        var change = Assert.Single(result.Changes);
        Assert.Equal(LocalStructuredSourceChangeKind.Baseline, change.ChangeKind);
        Assert.Equal(64, change.PathHash.Length);
    }

    private static async Task<ApiFixture> CreateFixtureAsync(
        IUiaSnapshotProvider? snapshotProvider = null,
        IUiaConversationDiagnosticsProvider? conversationDiagnosticsProvider = null,
        IUiaCandidateDiagnosticsProvider? uiaCandidateDiagnosticsProvider = null,
        IUiaTextCandidateDiagnosticsProvider? uiaTextCandidateDiagnosticsProvider = null,
        IDingTalkMessageNavigator? messageNavigator = null,
        IDingTalkLauncher? dingTalkLauncher = null,
        IDingTalkWindowRestorer? windowRestorer = null,
        IDevToolsTargetDiagnosticsProvider? devToolsTargetDiagnosticsProvider = null,
        ILocalStructuredSourceDiagnosticsProvider? localStructuredSourceDiagnosticsProvider = null,
        IClipboardMessageProbe? clipboardMessageProbe = null,
        ILatestMessageProbe? latestMessageProbe = null)
    {
        var database = await SqliteDatabase.CreateInMemoryAsync(CancellationToken.None);
        var hostBuilder = new HostBuilder()
            .ConfigureWebHost(webHost =>
            {
                webHost.UseTestServer();
                webHost.ConfigureServices(services =>
                {
                    services.AddRouting();
                    services.AddSingleton(database);
                    services.AddSingleton(new HostControlState());
                    services.AddSingleton<HostRuntimeStatus>();
                    services.AddSingleton(snapshotProvider ?? new StaticUiaSnapshotProvider());
                    services.AddSingleton<IWindowDiagnosticsProvider>(new StaticWindowDiagnosticsProvider());
                    services.AddSingleton<IWindowScreenshotService>(new StaticWindowScreenshotService());
                    services.AddSingleton(dingTalkLauncher ?? new StaticDingTalkLauncher());
                    services.AddSingleton(windowRestorer ?? new StaticDingTalkWindowRestorer());
                    services.AddSingleton(messageNavigator ?? new RecordingDingTalkMessageNavigator());
                    services.AddSingleton<IStructuredSourceProbe>(new StaticStructuredSourceProbe());
                    services.AddSingleton(
                        conversationDiagnosticsProvider ?? new StaticUiaConversationDiagnosticsProvider());
                    services.AddSingleton(
                        uiaCandidateDiagnosticsProvider ?? new StaticUiaCandidateDiagnosticsProvider());
                    services.AddSingleton(
                        uiaTextCandidateDiagnosticsProvider ?? new StaticUiaTextCandidateDiagnosticsProvider());
                    services.AddSingleton(
                        devToolsTargetDiagnosticsProvider ?? new StaticDevToolsTargetDiagnosticsProvider());
                    services.AddSingleton(
                        localStructuredSourceDiagnosticsProvider
                            ?? new StaticLocalStructuredSourceDiagnosticsProvider());
                    services.AddSingleton(clipboardMessageProbe ?? new RecordingClipboardMessageProbe());
                    services.AddSingleton(latestMessageProbe ?? NullLatestMessageProbe.Instance);
                    services.AddSingleton<RawEventsRepository>();
                    services.AddSingleton<ConversationTriggerSnapshotsRepository>();
                    services.AddSingleton<LatestMessageProbeService>();
                    services.AddSingleton(new LoopbackApiOptions("test-token"));
                });
                webHost.Configure(app =>
                {
                    app.UseRouting();
                    app.UseEndpoints(endpoints => endpoints.MapDingTalkHostLoopbackEndpoints());
                });
            });

        var host = await hostBuilder.StartAsync();
        return new ApiFixture(host, database, host.GetTestClient());
    }

    private sealed class ApiFixture : IAsyncDisposable
    {
        private readonly SqliteDatabase _database;

        public ApiFixture(IHost host, SqliteDatabase database, HttpClient client)
        {
            Host = host;
            _database = database;
            Client = client;
        }

        public IHost Host { get; }

        public HttpClient Client { get; }

        public async ValueTask DisposeAsync()
        {
            Client.Dispose();
            Host.Dispose();
            await _database.DisposeAsync();
        }
    }

    private sealed class StaticUiaSnapshotProvider : IUiaSnapshotProvider
    {
        public IReadOnlyList<string> GetNodeSummary(IntPtr windowHandle, int limit)
        {
            return new[] { "node-summary" };
        }

        public IReadOnlyList<string> GetMessageSurfaceNodeSummary(IntPtr windowHandle, int limit)
        {
            return new[] { "message-surface-node" };
        }
    }

    private sealed class RecordingUiaSnapshotProvider : IUiaSnapshotProvider
    {
        public IntPtr LastWindowHandle { get; private set; }

        public IntPtr LastMessageSurfaceWindowHandle { get; private set; }

        public IReadOnlyList<string> GetNodeSummary(IntPtr windowHandle, int limit)
        {
            LastWindowHandle = windowHandle;
            return new[] { "node-summary" };
        }

        public IReadOnlyList<string> GetMessageSurfaceNodeSummary(IntPtr windowHandle, int limit)
        {
            LastMessageSurfaceWindowHandle = windowHandle;
            return new[] { "message-surface-node" };
        }
    }

    private sealed class ThrowingUiaSnapshotProvider : IUiaSnapshotProvider
    {
        public IReadOnlyList<string> GetNodeSummary(IntPtr windowHandle, int limit)
        {
            throw new InvalidOperationException("probe failed");
        }

        public IReadOnlyList<string> GetMessageSurfaceNodeSummary(IntPtr windowHandle, int limit)
        {
            throw new InvalidOperationException("message surface probe failed");
        }
    }

    private sealed class StaticWindowDiagnosticsProvider : IWindowDiagnosticsProvider
    {
        public IReadOnlyList<string> GetCandidateSummary(int limit)
        {
            return new[] { "window-candidate" };
        }

        public WindowCandidateDiagnosticsResult GetCandidateDiagnostics(int limit)
        {
            return new WindowCandidateDiagnosticsResult(
                ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
                Health: WindowCandidateHealth.Ready,
                SelectedHwnd: "0x1234",
                Recommendation: "Ready to attach selected DingTalk window.",
                TotalDingTalkCandidates: 1,
                VisibleCandidates: 1,
                HiddenWorkspaceCandidates: 0,
                BlockingDialogCandidates: 0,
                RawSummaries: GetCandidateSummary(limit),
                RejectionReasonCounts: new Dictionary<WindowCandidateRejectionReason, int>
                {
                    [WindowCandidateRejectionReason.None] = 1,
                },
                Candidates: new[]
                {
                    new WindowCandidateDiagnostic(
                        Hwnd: "0x1234",
                        IsSelected: true,
                        Decision: WindowCandidateAttachmentDecision.Selected,
                        RejectionReason: WindowCandidateRejectionReason.None,
                        Title: "\u9489\u9489",
                        ClassName: "StandardFrame_DingTalk",
                        ProcessName: "DingTalk",
                        IsVisible: true,
                        IsEnabled: true,
                        IsTopLevel: true,
                        IsToolWindow: false,
                        Width: 900,
                        Height: 700,
                        ZOrder: 1),
                });
        }
    }

    private sealed class StaticDingTalkLauncher : IDingTalkLauncher
    {
        public DingTalkLauncherDiagnosticsResult GetDiagnostics()
        {
            return new DingTalkLauncherDiagnosticsResult(
                Readiness: DingTalkLauncherReadiness.Ready,
                IsConfigured: true,
                PathExists: true,
                RemoteDebuggingPort: 0,
                RendererAccessibilityEnabled: false,
                LauncherPath: "DingtalkLauncher.exe",
                Recommendation: "Launcher is ready.",
                ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"));
        }

        public DingTalkLaunchResult Launch()
        {
            return new DingTalkLaunchResult(
                Status: DingTalkLaunchStatus.Started,
                Message: "launcher invoked",
                LauncherPath: "DingtalkLauncher.exe",
                AttemptedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"));
        }

        public DingTalkLaunchResult Restart()
        {
            return new DingTalkLaunchResult(
                Status: DingTalkLaunchStatus.Started,
                Message: "launcher restarted",
                LauncherPath: "DingtalkLauncher.exe",
                AttemptedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"));
        }
    }

    private sealed class StaticDingTalkWindowRestorer : IDingTalkWindowRestorer
    {
        public DingTalkWindowRestoreResult Restore()
        {
            return new DingTalkWindowRestoreResult(
                Status: DingTalkWindowRestoreStatus.Restored,
                TargetHwnd: "0x902",
                Message: "window restored",
                AttemptedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"));
        }
    }

    private sealed class RecordingClipboardMessageProbe : IClipboardMessageProbe
    {
        public IntPtr LastWindowHandle { get; private set; }

        public ExtractedClipboardMessage? ProbeLatest(IntPtr windowHandle)
        {
            LastWindowHandle = windowHandle;
            return new ExtractedClipboardMessage(
                SourceConversationName: "(clipboard active chat)",
                SenderName: string.Empty,
                Text: "redacted message",
                ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
                SourceConversationIdHint: "windows:clipboard-active");
        }

        public ClipboardMessageProbeDiagnosticsResult GetDiagnostics(IntPtr windowHandle)
        {
            LastWindowHandle = windowHandle;
            return new ClipboardMessageProbeDiagnosticsResult(
                ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
                Enabled: true,
                TargetHwnd: "0x" + windowHandle.ToInt64().ToString("X"),
                Status: "Extracted",
                ClipboardChanged: true,
                CopiedTextLength: 24,
                CopiedTextHash: "def456",
                ExtractedTextLength: 16,
                ExtractedTextHash: "abc123",
                SourceConversationIdHint: "windows:clipboard-active",
                Error: string.Empty);
        }
    }

    private sealed class StaticLatestMessageProbe : ILatestMessageProbe
    {
        public LatestProbeMessage? ProbeLatest()
        {
            return new LatestProbeMessage(
                SourceConversationName: "Coordinated",
                SenderName: "Alice",
                Text: "coordinated latest",
                ObservedAt: DateTimeOffset.Parse("2026-05-16T10:00:00Z"),
                SourceConversationIdHint: "windows:coordinated");
        }
    }

    private sealed class NullLatestMessageProbe : ILatestMessageProbe
    {
        public static readonly NullLatestMessageProbe Instance = new();

        private NullLatestMessageProbe()
        {
        }

        public LatestProbeMessage? ProbeLatest()
        {
            return null;
        }
    }

    private sealed class ThrowingDingTalkWindowRestorer : IDingTalkWindowRestorer
    {
        public DingTalkWindowRestoreResult Restore()
        {
            throw new InvalidOperationException("restore endpoint failed");
        }
    }

    private sealed class RecordingDingTalkMessageNavigator : IDingTalkMessageNavigator
    {
        public IntPtr LastWindowHandle { get; private set; }

        public DingTalkNavigationResult OpenMessages(IntPtr windowHandle)
        {
            LastWindowHandle = windowHandle;
            return new DingTalkNavigationResult(
                Status: DingTalkNavigationStatus.Activated,
                TargetHwnd: "0x" + windowHandle.ToInt64().ToString("X"),
                TargetAutomationId: "navigator_view.im_im",
                Message: "Messages navigation item activated.",
                AttemptedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"));
        }

        public DingTalkNavigationResult CloseSearchOverlay(IntPtr windowHandle)
        {
            LastWindowHandle = windowHandle;
            return new DingTalkNavigationResult(
                Status: DingTalkNavigationStatus.Closed,
                TargetHwnd: "0x" + windowHandle.ToInt64().ToString("X"),
                TargetAutomationId: "advancedSearch",
                Message: "Search overlay closed.",
                AttemptedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"));
        }
    }

    private sealed class ThrowingDingTalkMessageNavigator : IDingTalkMessageNavigator
    {
        public DingTalkNavigationResult OpenMessages(IntPtr windowHandle)
        {
            throw new InvalidOperationException("open messages endpoint failed");
        }

        public DingTalkNavigationResult CloseSearchOverlay(IntPtr windowHandle)
        {
            throw new InvalidOperationException("close search overlay endpoint failed");
        }
    }

    private sealed class EmptyMessageThrowingDingTalkMessageNavigator : IDingTalkMessageNavigator
    {
        public DingTalkNavigationResult OpenMessages(IntPtr windowHandle)
        {
            throw new ExternalException();
        }

        public DingTalkNavigationResult CloseSearchOverlay(IntPtr windowHandle)
        {
            throw new ExternalException();
        }
    }

    private sealed class StaticStructuredSourceProbe : IStructuredSourceProbe
    {
        public StructuredSourceProbeResult Probe()
        {
            return new StructuredSourceProbeResult(
                ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
                Recommendation: "Probe Embedded Chromium DevTools before enabling OCR.",
                Signals: new[]
                {
                    new StructuredSourceProbeSignal(
                        Kind: StructuredSourceKind.EmbeddedChromium,
                        Status: StructuredSourceStatus.Candidate,
                        EstimatedLatencyMs: 200,
                        Evidence: "CefBrowserWindow window is present.",
                        NextAction: "Check whether DevTools or DOM hooks are exposed."),
                });
        }
    }

    private sealed class StaticDevToolsTargetDiagnosticsProvider : IDevToolsTargetDiagnosticsProvider
    {
        public DevToolsTargetDiagnosticsResult GetDiagnostics()
        {
            return new DevToolsTargetDiagnosticsResult(
                ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
                Status: StructuredSourceStatus.Candidate,
                Port: 9222,
                OwnerProcessId: 1001,
                Recommendation: "DingTalk-owned DevTools target metadata is available.",
                Targets: new[]
                {
                    new DevToolsTargetMetadata(
                        Id: "page-1",
                        Type: "page",
                        Title: "DingTalk",
                        Url: "https://example.invalid/chat",
                        HasWebSocketDebuggerUrl: true),
                });
        }
    }

    private sealed class StaticLocalStructuredSourceDiagnosticsProvider
        : ILocalStructuredSourceDiagnosticsProvider
    {
        public LocalStructuredSourceDiagnosticsResult GetDiagnostics(int candidateLimit)
        {
            return new LocalStructuredSourceDiagnosticsResult(
                ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
                Status: StructuredSourceStatus.NeedsManualApproval,
                CandidateCount: 1,
                Recommendation: "Read-only local source candidates require manual approval before parsing.",
                Candidates: new[]
                {
                    new LocalStructuredSourceCandidate(
                        Kind: LocalStructuredSourceCandidateKind.SqliteDatabase,
                        PathHint: "%LOCALAPPDATA%\\DingTalk\\message.sqlite",
                        SizeBytes: 4096,
                        LastWriteTime: DateTimeOffset.Parse("2026-05-15T09:00:00Z"),
                        Evidence: "extension=.sqlite sizeBytes=4096"),
                });
        }

        public LocalStructuredSourceChangeDiagnosticsResult GetChangeDiagnostics(
            int candidateLimit,
            bool resetBaseline)
        {
            return new LocalStructuredSourceChangeDiagnosticsResult(
                ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
                Status: StructuredSourceStatus.NeedsManualApproval,
                CandidateCount: 1,
                ChangedCount: resetBaseline ? 0 : 1,
                Recommendation: "Metadata-only change tracking; file paths and content are not returned.",
                Changes: new[]
                {
                    new LocalStructuredSourceChange(
                        Kind: LocalStructuredSourceCandidateKind.SqliteDatabase,
                        ChangeKind: resetBaseline
                            ? LocalStructuredSourceChangeKind.Baseline
                            : LocalStructuredSourceChangeKind.Modified,
                        PathHash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                        SizeBytes: 8192,
                        LastWriteTime: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
                        PreviousSizeBytes: resetBaseline ? 0 : 4096,
                        PreviousLastWriteTime: resetBaseline
                            ? null
                            : DateTimeOffset.Parse("2026-05-15T09:00:00Z")),
                });
        }

        public LocalStructuredSourceInspectionDiagnosticsResult GetInspectionDiagnostics(
            int candidateLimit,
            int itemLimit)
        {
            return new LocalStructuredSourceInspectionDiagnosticsResult(
                ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
                Status: StructuredSourceStatus.NeedsManualApproval,
                InspectedCount: 1,
                Recommendation: "SQLite schema metadata is available; content parsing still requires approval.",
                Inspections: new[]
                {
                    new LocalStructuredSourceInspection(
                        Kind: LocalStructuredSourceCandidateKind.SqliteDatabase,
                        Status: LocalStructuredSourceInspectionStatus.Inspected,
                        PathHint: "%LOCALAPPDATA%\\DingTalk\\message.sqlite",
                        Evidence: "schema-only inspection; values not read",
                        StructureItems: new[]
                        {
                            new LocalStructuredSourceStructureItem(
                                Kind: LocalStructuredSourceStructureKind.SqliteTable,
                                Name: "messages",
                                ChildNames: new[] { "id", "sender_name", "body_text" },
                                Evidence: "columnCount=3"),
                        }),
                });
        }

        public LocalStructuredContentShapeDiagnosticsResult GetContentShapeDiagnostics(
            int candidateLimit,
            int itemLimit,
            int sampleLimit)
        {
            return new LocalStructuredContentShapeDiagnosticsResult(
                ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
                Status: StructuredSourceStatus.NeedsManualApproval,
                ShapeCount: 1,
                Recommendation: "Content-shape metadata is available without values.",
                Shapes: new[]
                {
                    new LocalStructuredContentShape(
                        Kind: LocalStructuredSourceCandidateKind.SqliteDatabase,
                        Status: LocalStructuredContentShapeStatus.Candidate,
                        PathHash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                        PathHint: "%LOCALAPPDATA%\\DingTalk\\message.sqlite",
                        Evidence: "field hashes only",
                        Tables: new[]
                        {
                            new LocalStructuredContentTableShape(
                                Name: "messages",
                                RowCount: 2,
                                Score: 13,
                                Evidence: "roleScore=13 rowCount=2",
                                Fields: new[]
                                {
                                    new LocalStructuredContentFieldShape(
                                        Name: "body_text",
                                        Role: LocalStructuredContentFieldRole.Text,
                                        NonEmptySampleCount: 2,
                                        MinLength: 5,
                                        MaxLength: 6,
                                        SampleValueHashes: new[]
                                        {
                                            "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
                                        }),
                                }),
                        },
                        KeywordHits: Array.Empty<LocalStructuredContentKeywordHit>()),
                });
        }
    }

    private sealed class StaticUiaConversationDiagnosticsProvider : IUiaConversationDiagnosticsProvider
    {
        public UiaConversationDiagnosticsResult GetDiagnostics(IntPtr windowHandle, int limit)
        {
            return new UiaConversationDiagnosticsResult(
                ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
                Conversations: new[]
                {
                    new UiaConversationItem(
                        AutomationId: "conv-alpha",
                        Name: "Alpha Group",
                        IsSelected: true,
                        HasUnreadHint: false),
                },
                BlockingDialogs: new[]
                {
                    new UiaBlockingDialog(
                        Title: string.Empty,
                        Message: "Restart required.",
                        ClassName: "MsgBox"),
                },
                Recommendation: "Resolve blocking dialog before capture.");
        }
    }

    private sealed class ConversationOnlyUiaConversationDiagnosticsProvider : IUiaConversationDiagnosticsProvider
    {
        public UiaConversationDiagnosticsResult GetDiagnostics(IntPtr windowHandle, int limit)
        {
            return new UiaConversationDiagnosticsResult(
                ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
                Conversations: new[]
                {
                    new UiaConversationItem(
                        AutomationId: "conversation-listitem-1",
                        Name: "(unnamed conversation #1)",
                        IsSelected: false,
                        HasUnreadHint: false),
                    new UiaConversationItem(
                        AutomationId: "conversation-listitem-2",
                        Name: "(unnamed conversation #2)",
                        IsSelected: false,
                        HasUnreadHint: false),
                },
                BlockingDialogs: Array.Empty<UiaBlockingDialog>(),
                Recommendation: "Conversation list items are visible, but names are not exposed through UIA.");
        }
    }

    private sealed class StaticUiaCandidateDiagnosticsProvider : IUiaCandidateDiagnosticsProvider
    {
        public UiaCandidateDiagnosticsResult ProbeCandidates(
            int candidateLimit,
            int snapshotLimit,
            int conversationLimit)
        {
            return new UiaCandidateDiagnosticsResult(
                ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
                Recommendation: "Probe UIA-capable DingTalk content candidates.",
                HostedHwnd: "0x1234",
                SelectedWindowCandidateHwnd: "0x5678",
                TotalCandidates: 1,
                Probes: new[]
                {
                    new UiaCandidateProbe(
                        Hwnd: "0x5678",
                        Title: string.Empty,
                        ClassName: "CefBrowserWindow",
                        ProcessName: "DingTalk",
                        IsHosted: false,
                        IsSelectedWindowCandidate: true,
                        IsVisible: false,
                        IsTopLevel: false,
                        Width: 1024,
                        Height: 713,
                        Readiness: ConversationReadiness.NoConversationList,
                        ConversationCount: 0,
                        BlockingDialogCount: 0,
                        Recommendation: "Conversation list was not exposed through UIA for this window.",
                        NodeSummary: new[] { "candidate-node" },
                        Error: string.Empty),
                });
        }
    }

    private sealed class StaticUiaTextCandidateDiagnosticsProvider : IUiaTextCandidateDiagnosticsProvider
    {
        public UiaTextCandidateDiagnosticsResult GetDiagnostics(
            int candidateLimit,
            int snapshotLimit,
            int messageSurfaceLimit,
            int minimumTextLength)
        {
            return new UiaTextCandidateDiagnosticsResult(
                ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
                Status: StructuredSourceStatus.NeedsProbe,
                Recommendation: "Passive UIA exposed text-like nodes.",
                HostedHwnd: "0x1234",
                TotalWindowCandidates: 1,
                Windows: new[]
                {
                    new UiaTextCandidateWindow(
                        Hwnd: "0x5678",
                        ClassName: "DingChatWnd",
                        ProcessName: "DingTalk",
                        IsHosted: false,
                        IsVisible: true,
                        IsTopLevel: false,
                        Width: 1024,
                        Height: 713,
                        TextCandidateCount: 1,
                        PotentialMessageTextCount: 1,
                        TextCandidates: new[]
                        {
                            new UiaTextCandidate(
                                Source: UiaTextCandidateSource.MessageSurfaceSnapshot,
                                AutomationIdHash:
                                    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                                NameHash:
                                    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                                NameLength: 17,
                                ControlType: "Text",
                                ClassName: "QLabel",
                                ClassNameHash:
                                    "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
                                IsPotentialMessageText: true,
                                IsLikelyNoise: false),
                        },
                        Error: string.Empty),
                });
        }
    }

    private sealed class ThrowingUiaConversationDiagnosticsProvider : IUiaConversationDiagnosticsProvider
    {
        private readonly Exception _exception;

        public ThrowingUiaConversationDiagnosticsProvider(Exception exception)
        {
            _exception = exception;
        }

        public UiaConversationDiagnosticsResult GetDiagnostics(IntPtr windowHandle, int limit)
        {
            throw _exception;
        }
    }

    private sealed class StaticWindowScreenshotService : IWindowScreenshotService
    {
        public Task<WindowScreenshotResult?> CaptureAsync(
            IntPtr windowHandle,
            CancellationToken cancellationToken)
        {
            return Task.FromResult<WindowScreenshotResult?>(new WindowScreenshotResult(
                LocalImagePath: "capture.png",
                Sha256: "abc123",
                Width: 800,
                Height: 600,
                BytesWritten: 42,
                CapturedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z")));
        }

        public Task<WindowScreenshotResult?> CaptureChatAreaAsync(
            IntPtr windowHandle,
            CancellationToken cancellationToken)
        {
            return CaptureAsync(windowHandle, cancellationToken);
        }
    }

    private static DingTalkObservedEvent CreateEvent(
        string eventId = "evt-1",
        string text = "hello",
        CaptureSource captureSource = CaptureSource.UiaText,
        string senderName = "Alice",
        string sourceConversationId = "chat-alpha")
    {
        return new DingTalkObservedEvent(
            EventId: eventId,
            SourceConversationId: sourceConversationId,
            SourceConversationName: "Alpha",
            EmbeddedSourceName: string.Empty,
            SenderName: senderName,
            ObservedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
            Text: text,
            LocalImagePath: string.Empty,
            CaptureSource: captureSource,
            ContentHash: "hash-" + text);
    }
}
