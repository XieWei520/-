using DingTalkWindowsHost.Contracts.Services;
using DingTalkWindowsHost.Storage.Db;
using DingTalkWindowsHost.Storage.Repositories;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace DingTalkWindowsHost.Api;

public sealed class LoopbackApiHost : IAsyncDisposable
{
    private readonly WebApplication _app;

    private LoopbackApiHost(WebApplication app)
    {
        _app = app;
    }

    public static LoopbackApiHost Create(
        SqliteDatabase database,
        HostControlState controlState,
        HostRuntimeStatus runtimeStatus,
        IUiaSnapshotProvider snapshotProvider,
        IWindowDiagnosticsProvider windowDiagnosticsProvider,
        IDingTalkLauncher dingTalkLauncher,
        IDingTalkWindowRestorer dingTalkWindowRestorer,
        IDingTalkMessageNavigator dingTalkMessageNavigator,
        IWindowScreenshotService windowScreenshotService,
        IStructuredSourceProbe structuredSourceProbe,
        IDevToolsTargetDiagnosticsProvider devToolsTargetDiagnosticsProvider,
        ILocalStructuredSourceDiagnosticsProvider localStructuredSourceDiagnosticsProvider,
        IUiaConversationDiagnosticsProvider conversationDiagnosticsProvider,
        IUiaCandidateDiagnosticsProvider uiaCandidateDiagnosticsProvider,
        IUiaTextCandidateDiagnosticsProvider uiaTextCandidateDiagnosticsProvider,
        IClipboardMessageProbe clipboardMessageProbe,
        ILatestMessageProbe latestMessageProbe,
        LoopbackApiOptions options)
    {
        ArgumentNullException.ThrowIfNull(database);
        ArgumentNullException.ThrowIfNull(controlState);
        ArgumentNullException.ThrowIfNull(runtimeStatus);
        ArgumentNullException.ThrowIfNull(snapshotProvider);
        ArgumentNullException.ThrowIfNull(windowDiagnosticsProvider);
        ArgumentNullException.ThrowIfNull(dingTalkLauncher);
        ArgumentNullException.ThrowIfNull(dingTalkWindowRestorer);
        ArgumentNullException.ThrowIfNull(dingTalkMessageNavigator);
        ArgumentNullException.ThrowIfNull(windowScreenshotService);
        ArgumentNullException.ThrowIfNull(structuredSourceProbe);
        ArgumentNullException.ThrowIfNull(devToolsTargetDiagnosticsProvider);
        ArgumentNullException.ThrowIfNull(localStructuredSourceDiagnosticsProvider);
        ArgumentNullException.ThrowIfNull(conversationDiagnosticsProvider);
        ArgumentNullException.ThrowIfNull(uiaCandidateDiagnosticsProvider);
        ArgumentNullException.ThrowIfNull(uiaTextCandidateDiagnosticsProvider);
        ArgumentNullException.ThrowIfNull(clipboardMessageProbe);
        ArgumentNullException.ThrowIfNull(latestMessageProbe);
        ArgumentNullException.ThrowIfNull(options);

        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            ApplicationName = typeof(LoopbackApiMarker).Assembly.GetName().Name,
        });
        builder.WebHost.UseUrls("http://127.0.0.1:17651");
        builder.Services.AddSingleton(database);
        builder.Services.AddSingleton(controlState);
        builder.Services.AddSingleton(runtimeStatus);
        builder.Services.AddSingleton(snapshotProvider);
        builder.Services.AddSingleton(windowDiagnosticsProvider);
        builder.Services.AddSingleton(dingTalkLauncher);
        builder.Services.AddSingleton(dingTalkWindowRestorer);
        builder.Services.AddSingleton(dingTalkMessageNavigator);
        builder.Services.AddSingleton(windowScreenshotService);
        builder.Services.AddSingleton(structuredSourceProbe);
        builder.Services.AddSingleton(devToolsTargetDiagnosticsProvider);
        builder.Services.AddSingleton(localStructuredSourceDiagnosticsProvider);
        builder.Services.AddSingleton(conversationDiagnosticsProvider);
        builder.Services.AddSingleton(uiaCandidateDiagnosticsProvider);
        builder.Services.AddSingleton(uiaTextCandidateDiagnosticsProvider);
        builder.Services.AddSingleton(clipboardMessageProbe);
        builder.Services.AddSingleton(latestMessageProbe);
        builder.Services.AddSingleton(options);
        builder.Services.AddSingleton<RawEventsRepository>();
        builder.Services.AddSingleton<ConversationTriggerSnapshotsRepository>();
        builder.Services.AddSingleton<LatestMessageProbeService>();

        var app = builder.Build();
        app.MapDingTalkHostLoopbackEndpoints();
        return new LoopbackApiHost(app);
    }

    public Task StartAsync(CancellationToken cancellationToken)
    {
        return _app.StartAsync(cancellationToken);
    }

    public async ValueTask DisposeAsync()
    {
        await _app.DisposeAsync();
    }
}
