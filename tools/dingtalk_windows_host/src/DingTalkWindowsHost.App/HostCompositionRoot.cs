using System.IO;
using DingTalkWindowsHost.Api;
using DingTalkWindowsHost.Automation;
using DingTalkWindowsHost.App.ViewModels;
using DingTalkWindowsHost.Storage;
using DingTalkWindowsHost.Storage.Db;
using DingTalkWindowsHost.Storage.Repositories;

namespace DingTalkWindowsHost.App;

internal sealed class HostCompositionRoot : IAsyncDisposable
{
    private HostCompositionRoot(
        SqliteDatabase database,
        RawEventsRepository rawEventsRepository,
        HostControlState controlState,
        HostRuntimeStatus runtimeStatus,
        LoopbackApiHost apiHost,
        HostAutomation automation,
        DingTalkWindowsHost.Automation.Capture.UiaConversationDiagnosticsProvider conversationDiagnosticsProvider,
        DingTalkWindowsHost.Automation.Capture.UiaCandidateDiagnosticsProvider uiaCandidateDiagnosticsProvider,
        ConversationTriggerSnapshotsRepository conversationTriggerSnapshotsRepository)
    {
        Database = database;
        RawEventsRepository = rawEventsRepository;
        ControlState = controlState;
        RuntimeStatus = runtimeStatus;
        ApiHost = apiHost;
        Automation = automation;
        ConversationDiagnosticsProvider = conversationDiagnosticsProvider;
        UiaCandidateDiagnosticsProvider = uiaCandidateDiagnosticsProvider;
        ConversationTriggerSnapshotsRepository = conversationTriggerSnapshotsRepository;
    }

    public SqliteDatabase Database { get; }

    public RawEventsRepository RawEventsRepository { get; }

    public HostControlState ControlState { get; }

    public HostRuntimeStatus RuntimeStatus { get; }

    public LoopbackApiHost ApiHost { get; }

    public HostAutomation Automation { get; }

    public DingTalkWindowsHost.Automation.Capture.UiaConversationDiagnosticsProvider ConversationDiagnosticsProvider { get; }

    public DingTalkWindowsHost.Automation.Capture.UiaCandidateDiagnosticsProvider UiaCandidateDiagnosticsProvider { get; }

    public ConversationTriggerSnapshotsRepository ConversationTriggerSnapshotsRepository { get; }

    public MainWindowViewModel CreateMainWindowViewModel()
    {
        return new MainWindowViewModel(
            Automation.WindowSupervisor,
            Automation.MessageProbeCoordinator,
            Automation.ScreenshotOcrCapturePipeline,
            Automation.EventNormalizer,
            RawEventsRepository,
            ConversationTriggerSnapshotsRepository,
            ControlState,
            RuntimeStatus,
            new DingTalkWindowsHost.Automation.StructuredSources.StructuredSourceProbe(
                () => Automation.ScreenshotOcrCapturePipeline.IsEnabled),
            ConversationDiagnosticsProvider,
            new DingTalkWindowsHost.Automation.WindowHost.WindowDiagnosticsProvider(
                Automation.WindowLocator,
                RuntimeStatus.GetCurrentHwnd),
            new DingTalkWindowsHost.Automation.WindowHost.DingTalkLauncher(
                DingTalkWindowsHost.Automation.WindowHost.DingTalkLauncherOptions.FromEnvironment()),
            new DingTalkWindowsHost.Automation.WindowHost.DingTalkWindowRestorer(Automation.WindowLocator));
    }

    public async ValueTask DisposeAsync()
    {
        Automation.WindowSupervisor.RequestStop();
        _ = Automation.WindowSupervisor.Tick(
            IntPtr.Zero,
            new DingTalkWindowsHost.Automation.WindowHost.HostSurfaceBounds(1, 1));
        await ApiHost.DisposeAsync();
        await Database.DisposeAsync();
    }

    public static async Task<HostCompositionRoot> CreateAsync(CancellationToken cancellationToken)
    {
        var databasePath = Path.Combine(
            AppContext.BaseDirectory,
            "runtime",
            "dingtalk-host.sqlite");
        var database = await SqliteDatabase.CreateAsync(databasePath, cancellationToken);
        var rawEventsRepository = new RawEventsRepository(database);
        var conversationTriggerSnapshotsRepository = new ConversationTriggerSnapshotsRepository(database);
        var controlState = new HostControlState();
        var capturesPath = Path.Combine(AppContext.BaseDirectory, "runtime", "captures");
        var windowAttachmentJournal = new DingTalkWindowsHost.Automation.WindowHost.WindowAttachmentJournal(
            Path.Combine(AppContext.BaseDirectory, "runtime", "window-attachment.json"));
        var baseScreenshotService = new DingTalkWindowsHost.Automation.Capture.WindowScreenshotService(
            new DingTalkWindowsHost.Automation.Capture.CaptureFileStore(capturesPath));
        var screenshotService = new DingTalkWindowsHost.Automation.Capture.FallbackWindowScreenshotService(
            baseScreenshotService,
            new DingTalkWindowsHost.Automation.WindowHost.DingTalkWindowLocator());
        var automation = new HostAutomation(
            screenshotService,
            DingTalkWindowsHost.Automation.Ocr.ExternalCommandOcrService.FromEnvironment(),
            windowAttachmentJournal);
        var runtimeStatus = new HostRuntimeStatus(
            () => automation.ScreenshotOcrCapturePipeline.IsEnabled);
        var conversationDiagnosticsProvider =
            new DingTalkWindowsHost.Automation.Capture.UiaConversationDiagnosticsProvider(
                automation.ChatSurfaceProbe);
        var uiaCandidateDiagnosticsProvider =
            new DingTalkWindowsHost.Automation.Capture.UiaCandidateDiagnosticsProvider(
                automation.WindowLocator,
                automation.ChatSurfaceProbe,
                runtimeStatus.GetCurrentHwnd);
        var uiaTextCandidateDiagnosticsProvider =
            new DingTalkWindowsHost.Automation.Capture.UiaTextCandidateDiagnosticsProvider(
                automation.WindowLocator,
                automation.ChatSurfaceProbe,
                runtimeStatus.GetCurrentHwnd);
        var apiHost = LoopbackApiHost.Create(
            database,
            controlState,
            runtimeStatus,
            new DingTalkWindowsHost.Automation.Capture.UiaSnapshotProvider(automation.ChatSurfaceProbe),
            new DingTalkWindowsHost.Automation.WindowHost.WindowDiagnosticsProvider(
                automation.WindowLocator,
                runtimeStatus.GetCurrentHwnd),
            new DingTalkWindowsHost.Automation.WindowHost.DingTalkLauncher(
                DingTalkWindowsHost.Automation.WindowHost.DingTalkLauncherOptions.FromEnvironment()),
            new DingTalkWindowsHost.Automation.WindowHost.DingTalkWindowRestorer(automation.WindowLocator),
            new DingTalkWindowsHost.Automation.WindowHost.DingTalkMessageNavigator(automation.WindowLocator),
            screenshotService,
            new DingTalkWindowsHost.Automation.StructuredSources.StructuredSourceProbe(
                () => automation.ScreenshotOcrCapturePipeline.IsEnabled),
            new DingTalkWindowsHost.Automation.StructuredSources.DevToolsTargetDiagnosticsProvider(),
            new DingTalkWindowsHost.Automation.StructuredSources.LocalStructuredSourceDiagnosticsProvider(),
            conversationDiagnosticsProvider,
            uiaCandidateDiagnosticsProvider,
            uiaTextCandidateDiagnosticsProvider,
            automation.ClipboardMessageProbe,
            new DingTalkWindowsHost.Automation.Capture.LatestMessageProbeAdapter(
                automation.MessageProbeCoordinator),
            LoopbackApiOptions.CreateDefault());
        await apiHost.StartAsync(cancellationToken);

        return new HostCompositionRoot(
            database,
            rawEventsRepository,
            controlState,
            runtimeStatus,
            apiHost,
            automation,
            conversationDiagnosticsProvider,
            uiaCandidateDiagnosticsProvider,
            conversationTriggerSnapshotsRepository);
    }
}
