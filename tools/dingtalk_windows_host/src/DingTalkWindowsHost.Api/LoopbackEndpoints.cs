using DingTalkWindowsHost.Contracts.Services;
using DingTalkWindowsHost.Storage.Repositories;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace DingTalkWindowsHost.Api;

public static class LoopbackEndpoints
{
    public static IEndpointRouteBuilder MapDingTalkHostLoopbackEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/status", (
            HttpRequest request,
            HostControlState controlState,
            HostRuntimeStatus runtimeStatus,
            LoopbackApiOptions options) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            return Results.Ok(runtimeStatus.ToDto(controlState.CaptureRunning));
        });

        endpoints.MapGet("/events/recent", async (
            HttpRequest request,
            RawEventsRepository repository,
            LoopbackApiOptions options,
            int? limit,
            CancellationToken cancellationToken) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            var events = await repository.ListRecentAsync(limit ?? 50, cancellationToken);
            return Results.Ok(events);
        });

        endpoints.MapGet("/events/forwardable-recent", async (
            HttpRequest request,
            RawEventsRepository repository,
            LoopbackApiOptions options,
            int? limit,
            CancellationToken cancellationToken) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            var events = await repository.ListForwardableRecentAsync(limit ?? 50, cancellationToken);
            return Results.Ok(events);
        });

        endpoints.MapGet("/conversation-triggers/recent", async (
            HttpRequest request,
            ConversationTriggerSnapshotsRepository repository,
            LoopbackApiOptions options,
            int? limit,
            CancellationToken cancellationToken) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            var snapshots = await repository.ListRecentAsync(limit ?? 50, cancellationToken);
            return Results.Ok(snapshots);
        });

        endpoints.MapGet("/diagnostics/uia-snapshot", (
            HttpRequest request,
            HostRuntimeStatus runtimeStatus,
            LoopbackApiOptions options,
            IUiaSnapshotProvider snapshotProvider,
            int? limit,
            string? hwnd) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            try
            {
                var windowHandle = TryParseHandle(hwnd, out var parsedHandle)
                    ? parsedHandle
                    : runtimeStatus.GetCurrentHwnd();
                var summary = snapshotProvider.GetNodeSummary(windowHandle, limit ?? 80);
                return Results.Ok(summary);
            }
            catch (Exception ex)
            {
                return Results.Ok(new[]
                {
                    "uia-snapshot-error type='"
                    + ex.GetType().Name
                    + "' message='"
                    + FormatExceptionForDiagnostics(ex)
                    + "'",
                });
            }
        });

        endpoints.MapGet("/diagnostics/uia-message-surface", (
            HttpRequest request,
            HostRuntimeStatus runtimeStatus,
            LoopbackApiOptions options,
            IUiaSnapshotProvider snapshotProvider,
            int? limit,
            string? hwnd) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            try
            {
                var windowHandle = TryParseHandle(hwnd, out var parsedHandle)
                    ? parsedHandle
                    : runtimeStatus.GetCurrentHwnd();
                var summary = snapshotProvider.GetMessageSurfaceNodeSummary(windowHandle, limit ?? 240);
                return Results.Ok(summary);
            }
            catch (Exception ex)
            {
                return Results.Ok(new[]
                {
                    "uia-message-surface-error type='"
                    + ex.GetType().Name
                    + "' message='"
                    + FormatExceptionForDiagnostics(ex)
                    + "'",
                });
            }
        });

        endpoints.MapGet("/diagnostics/window-candidates", (
            HttpRequest request,
            LoopbackApiOptions options,
            IWindowDiagnosticsProvider windowDiagnosticsProvider,
            int? limit) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            return Results.Ok(windowDiagnosticsProvider.GetCandidateSummary(limit ?? 80));
        });

        endpoints.MapGet("/diagnostics/window-state", (
            HttpRequest request,
            LoopbackApiOptions options,
            IWindowDiagnosticsProvider windowDiagnosticsProvider,
            int? limit) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            return Results.Ok(windowDiagnosticsProvider.GetCandidateDiagnostics(limit ?? 80));
        });

        endpoints.MapGet("/diagnostics/conversations", async (
            HttpRequest request,
            HostRuntimeStatus runtimeStatus,
            LoopbackApiOptions options,
            IUiaConversationDiagnosticsProvider conversationDiagnosticsProvider,
            ConversationTriggerSnapshotsRepository conversationTriggerSnapshotsRepository,
            int? limit,
            string? hwnd,
            CancellationToken cancellationToken) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            var windowHandle = TryParseHandle(hwnd, out var parsedHandle)
                ? parsedHandle
                : runtimeStatus.GetCurrentHwnd();
            try
            {
                var diagnostics = conversationDiagnosticsProvider.GetDiagnostics(windowHandle, limit ?? 50);
                runtimeStatus.UpdateConversationDiagnostics(diagnostics);
                await conversationTriggerSnapshotsRepository.AddIfChangedAsync(diagnostics, cancellationToken);
                return Results.Ok(diagnostics);
            }
            catch (Exception ex)
            {
                var degraded = BuildConversationDiagnosticsError(ex);
                runtimeStatus.UpdateConversationDiagnostics(degraded);
                return Results.Ok(degraded);
            }
        });

        endpoints.MapGet("/diagnostics/uia-candidates", (
            HttpRequest request,
            LoopbackApiOptions options,
            IUiaCandidateDiagnosticsProvider uiaCandidateDiagnosticsProvider,
            int? limit,
            int? snapshotLimit,
            int? conversationLimit) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            return Results.Ok(uiaCandidateDiagnosticsProvider.ProbeCandidates(
                limit ?? 8,
                snapshotLimit ?? 20,
                conversationLimit ?? 20));
        });

        endpoints.MapGet("/diagnostics/uia-text-candidates", (
            HttpRequest request,
            LoopbackApiOptions options,
            IUiaTextCandidateDiagnosticsProvider uiaTextCandidateDiagnosticsProvider,
            int? limit,
            int? snapshotLimit,
            int? messageSurfaceLimit,
            int? minimumTextLength) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            return Results.Ok(uiaTextCandidateDiagnosticsProvider.GetDiagnostics(
                limit ?? 12,
                snapshotLimit ?? 300,
                messageSurfaceLimit ?? 300,
                minimumTextLength ?? 2));
        });

        endpoints.MapPost("/diagnostics/clipboard-probe", (
            HttpRequest request,
            HostRuntimeStatus runtimeStatus,
            LoopbackApiOptions options,
            IClipboardMessageProbe clipboardMessageProbe,
            string? hwnd) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            var windowHandle = TryParseHandle(hwnd, out var parsedHandle)
                ? parsedHandle
                : runtimeStatus.GetCurrentHwnd();
            return Results.Ok(clipboardMessageProbe.GetDiagnostics(windowHandle));
        });

        endpoints.MapPost("/control/probe-latest", async (
            HttpRequest request,
            HostRuntimeStatus runtimeStatus,
            LoopbackApiOptions options,
            LatestMessageProbeService latestMessageProbeService,
            string? hwnd,
            CancellationToken cancellationToken) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            var windowHandle = TryParseHandle(hwnd, out var parsedHandle)
                ? parsedHandle
                : runtimeStatus.GetCurrentHwnd();
            return Results.Ok(await latestMessageProbeService.ProbeLatestAsync(
                windowHandle,
                cancellationToken));
        });

        endpoints.MapPost("/diagnostics/screenshot", async (
            HttpRequest request,
            HostRuntimeStatus runtimeStatus,
            LoopbackApiOptions options,
            IWindowScreenshotService windowScreenshotService,
            string? hwnd,
            CancellationToken cancellationToken) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            var windowHandle = TryParseHandle(hwnd, out var parsedHandle)
                ? parsedHandle
                : runtimeStatus.GetCurrentHwnd();
            var screenshot = await windowScreenshotService.CaptureAsync(windowHandle, cancellationToken);
            return screenshot is null
                ? Results.NotFound()
                : Results.Ok(screenshot);
        });

        endpoints.MapPost("/diagnostics/chat-screenshot", async (
            HttpRequest request,
            HostRuntimeStatus runtimeStatus,
            LoopbackApiOptions options,
            IWindowScreenshotService windowScreenshotService,
            string? hwnd,
            CancellationToken cancellationToken) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            var windowHandle = TryParseHandle(hwnd, out var parsedHandle)
                ? parsedHandle
                : runtimeStatus.GetCurrentHwnd();
            var screenshot = await windowScreenshotService.CaptureChatAreaAsync(windowHandle, cancellationToken);
            return screenshot is null
                ? Results.NotFound()
                : Results.Ok(screenshot);
        });

        endpoints.MapGet("/diagnostics/structured-sources", (
            HttpRequest request,
            LoopbackApiOptions options,
            IStructuredSourceProbe structuredSourceProbe) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            return Results.Ok(structuredSourceProbe.Probe());
        });

        endpoints.MapGet("/diagnostics/devtools-targets", (
            HttpRequest request,
            LoopbackApiOptions options,
            IDevToolsTargetDiagnosticsProvider devToolsTargetDiagnosticsProvider) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            return Results.Ok(devToolsTargetDiagnosticsProvider.GetDiagnostics());
        });

        endpoints.MapGet("/diagnostics/local-structured-sources", (
            HttpRequest request,
            LoopbackApiOptions options,
            ILocalStructuredSourceDiagnosticsProvider localStructuredSourceDiagnosticsProvider,
            int? limit) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            return Results.Ok(localStructuredSourceDiagnosticsProvider.GetDiagnostics(limit ?? 50));
        });

        endpoints.MapGet("/diagnostics/local-structured-source-changes", (
            HttpRequest request,
            LoopbackApiOptions options,
            ILocalStructuredSourceDiagnosticsProvider localStructuredSourceDiagnosticsProvider,
            int? limit,
            bool? resetBaseline) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            return Results.Ok(localStructuredSourceDiagnosticsProvider.GetChangeDiagnostics(
                limit ?? 80,
                resetBaseline ?? false));
        });

        endpoints.MapGet("/diagnostics/local-structured-source-inspection", (
            HttpRequest request,
            LoopbackApiOptions options,
            ILocalStructuredSourceDiagnosticsProvider localStructuredSourceDiagnosticsProvider,
            int? limit,
            int? itemLimit) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            return Results.Ok(localStructuredSourceDiagnosticsProvider.GetInspectionDiagnostics(
                limit ?? 20,
                itemLimit ?? 40));
        });

        endpoints.MapGet("/diagnostics/local-structured-content-shape", (
            HttpRequest request,
            LoopbackApiOptions options,
            ILocalStructuredSourceDiagnosticsProvider localStructuredSourceDiagnosticsProvider,
            int? limit,
            int? itemLimit,
            int? sampleLimit) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            return Results.Ok(localStructuredSourceDiagnosticsProvider.GetContentShapeDiagnostics(
                limit ?? 20,
                itemLimit ?? 40,
                sampleLimit ?? 5));
        });

        endpoints.MapGet("/diagnostics/launcher", (
            HttpRequest request,
            LoopbackApiOptions options,
            IDingTalkLauncher dingTalkLauncher) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            return Results.Ok(dingTalkLauncher.GetDiagnostics());
        });

        endpoints.MapPost("/control/start", (
            HttpRequest request,
            HostControlState controlState,
            HostRuntimeStatus runtimeStatus,
            LoopbackApiOptions options) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            controlState.Start();
            return Results.Ok(runtimeStatus.ToDto(controlState.CaptureRunning));
        });

        endpoints.MapPost("/control/stop", (
            HttpRequest request,
            HostControlState controlState,
            HostRuntimeStatus runtimeStatus,
            LoopbackApiOptions options) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            controlState.Stop();
            return Results.Ok(runtimeStatus.ToDto(controlState.CaptureRunning));
        });

        endpoints.MapPost("/control/reload", (
            HttpRequest request,
            HostControlState controlState,
            HostRuntimeStatus runtimeStatus,
            LoopbackApiOptions options) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            controlState.Reload();
            return Results.Ok(runtimeStatus.ToDto(controlState.CaptureRunning));
        });

        endpoints.MapPost("/control/launch-dingtalk", (
            HttpRequest request,
            LoopbackApiOptions options,
            IDingTalkLauncher dingTalkLauncher) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            return Results.Ok(dingTalkLauncher.Launch());
        });

        endpoints.MapPost("/control/restart-dingtalk", (
            HttpRequest request,
            LoopbackApiOptions options,
            IDingTalkLauncher dingTalkLauncher) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            return Results.Ok(dingTalkLauncher.Restart());
        });

        endpoints.MapPost("/control/restore-dingtalk-window", (
            HttpRequest request,
            LoopbackApiOptions options,
            IDingTalkWindowRestorer dingTalkWindowRestorer) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            try
            {
                return Results.Ok(dingTalkWindowRestorer.Restore());
            }
            catch (Exception ex)
            {
                return Results.Ok(new Contracts.Models.DingTalkWindowRestoreResult(
                    Status: Contracts.Models.DingTalkWindowRestoreStatus.Failed,
                    TargetHwnd: string.Empty,
                    Message: "DingTalk window restore endpoint failed: "
                        + FormatExceptionForDiagnostics(ex),
                    AttemptedAt: DateTimeOffset.UtcNow));
            }
        });

        endpoints.MapPost("/control/open-messages", (
            HttpRequest request,
            HostRuntimeStatus runtimeStatus,
            LoopbackApiOptions options,
            IDingTalkMessageNavigator dingTalkMessageNavigator,
            string? hwnd) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            var windowHandle = TryParseHandle(hwnd, out var parsedHandle)
                ? parsedHandle
                : runtimeStatus.GetCurrentHwnd();
            try
            {
                return Results.Ok(dingTalkMessageNavigator.OpenMessages(windowHandle));
            }
            catch (Exception ex)
            {
                return Results.Ok(new Contracts.Models.DingTalkNavigationResult(
                    Status: Contracts.Models.DingTalkNavigationStatus.Failed,
                    TargetHwnd: FormatHandle(windowHandle),
                    TargetAutomationId: "navigator_view.im_im",
                    Message: "DingTalk open messages endpoint failed: "
                        + FormatExceptionForDiagnostics(ex),
                    AttemptedAt: DateTimeOffset.UtcNow));
            }
        });

        endpoints.MapPost("/control/close-search-overlay", (
            HttpRequest request,
            HostRuntimeStatus runtimeStatus,
            LoopbackApiOptions options,
            IDingTalkMessageNavigator dingTalkMessageNavigator,
            string? hwnd) =>
        {
            if (!IsAuthorized(request, options))
            {
                return Results.Unauthorized();
            }

            var windowHandle = TryParseHandle(hwnd, out var parsedHandle)
                ? parsedHandle
                : runtimeStatus.GetCurrentHwnd();
            try
            {
                return Results.Ok(dingTalkMessageNavigator.CloseSearchOverlay(windowHandle));
            }
            catch (Exception ex)
            {
                return Results.Ok(new Contracts.Models.DingTalkNavigationResult(
                    Status: Contracts.Models.DingTalkNavigationStatus.Failed,
                    TargetHwnd: FormatHandle(windowHandle),
                    TargetAutomationId: "advancedSearch",
                    Message: "DingTalk close search overlay endpoint failed: "
                        + FormatExceptionForDiagnostics(ex),
                    AttemptedAt: DateTimeOffset.UtcNow));
            }
        });

        return endpoints;
    }

    private static bool IsAuthorized(HttpRequest request, LoopbackApiOptions options)
    {
        if (string.IsNullOrWhiteSpace(options.LocalToken))
        {
            return false;
        }

        return request.Headers.TryGetValue(LoopbackApiOptions.TokenHeaderName, out var providedToken)
            && string.Equals(providedToken.ToString(), options.LocalToken, StringComparison.Ordinal);
    }

    private static bool TryParseHandle(string? value, out IntPtr handle)
    {
        handle = IntPtr.Zero;
        if (string.IsNullOrWhiteSpace(value))
        {
            return false;
        }

        var normalized = value.StartsWith("0x", StringComparison.OrdinalIgnoreCase)
            ? value[2..]
            : value;

        if (!long.TryParse(
                normalized,
                System.Globalization.NumberStyles.HexNumber,
                System.Globalization.CultureInfo.InvariantCulture,
                out var parsedValue))
        {
            return false;
        }

        handle = new IntPtr(parsedValue);
        return handle != IntPtr.Zero;
    }

    private static string FormatHandle(IntPtr handle)
    {
        return handle == IntPtr.Zero ? "0x0" : "0x" + handle.ToInt64().ToString("X");
    }

    private static Contracts.Models.UiaConversationDiagnosticsResult BuildConversationDiagnosticsError(Exception ex)
    {
        return new Contracts.Models.UiaConversationDiagnosticsResult(
            ObservedAt: DateTimeOffset.UtcNow,
            Conversations: Array.Empty<Contracts.Models.UiaConversationItem>(),
            BlockingDialogs: Array.Empty<Contracts.Models.UiaBlockingDialog>(),
            Recommendation: "conversation-diagnostics-error type='"
                + ex.GetType().Name
                + "' message='"
                + FormatExceptionForDiagnostics(ex)
                + "'");
    }

    private static string FormatExceptionForDiagnostics(Exception exception)
    {
        var message = exception.Message;
        return string.IsNullOrWhiteSpace(message)
            ? exception.GetType().Name + " HResult=0x" + exception.HResult.ToString("X8")
            : exception.GetType().Name
                + " HResult=0x"
                + exception.HResult.ToString("X8")
                + " Message="
                + message;
    }
}
