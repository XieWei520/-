using System;
using System.ComponentModel;
using System.Net.Http;
using System.Runtime.CompilerServices;
using System.Windows.Input;
using System.Windows.Threading;
using DingTalkWindowsHost.Automation.Capture;
using DingTalkWindowsHost.Automation.WindowHost;
using DingTalkWindowsHost.Api;
using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Contracts.Services;
using DingTalkWindowsHost.Storage.Repositories;

namespace DingTalkWindowsHost.App.ViewModels;

public sealed class MainWindowViewModel : INotifyPropertyChanged, IDisposable
{
    private static readonly TimeSpan CapturePollInterval = TimeSpan.FromSeconds(2);
    private static readonly TimeSpan StructuredSourceRefreshInterval = TimeSpan.FromSeconds(5);

    private readonly object _captureGate = new();
    private readonly HostControlState _controlState;
    private readonly UiaMessageProbeCoordinator _messageProbeCoordinator;
    private readonly EventNormalizer _eventNormalizer;
    private readonly ConversationTriggerSnapshotsRepository _conversationTriggerSnapshotsRepository;
    private readonly RawEventsRepository _rawEventsRepository;
    private readonly HostRuntimeStatus _runtimeStatus;
    private readonly ScreenshotOcrCapturePipeline _screenshotOcrCapturePipeline;
    private readonly IStructuredSourceProbe _structuredSourceProbe;
    private readonly IUiaConversationDiagnosticsProvider _conversationDiagnosticsProvider;
    private readonly IWindowDiagnosticsProvider _windowDiagnosticsProvider;
    private readonly IDingTalkLauncher _dingTalkLauncher;
    private readonly IDingTalkWindowRestorer _dingTalkWindowRestorer;
    private readonly DispatcherTimer _supervisorTimer;
    private readonly WindowSupervisor _windowSupervisor;
    private DateTimeOffset _lastCaptureAttemptAt = DateTimeOffset.MinValue;
    private DateTimeOffset _lastStructuredSourceRefreshAt = DateTimeOffset.MinValue;
    private IntPtr _hostSurfaceHandle;
    private HostSurfaceBounds _hostSurfaceBounds = new(1024, 720);
    private bool _hostSurfacePaused;
    private DingTalkObservedEvent? _lastObservedEvent;
    private bool _screenshotFallbackInFlight;
    private DateTimeOffset _lastScreenshotFallbackAttemptAt = DateTimeOffset.MinValue;
    private string _currentHwndText = "n/a";
    private string _lastEventTimeText = "n/a";
    private string _shellStateText = WindowSupervisorShellState.Stopped.ToString();
    private string _conversationDiagnosticsText = "Conversation diagnostics have not run yet.";
    private string _statusText = "Host shell is idle.";
    private string _structuredSourcesText = "Structured source probe has not run yet.";
    private string _windowDiagnosticsText = "Window diagnostics have not run yet.";
    private string _launcherStatusText = "DingTalk launcher has not run yet.";
    private string _surfaceStatusText = "No DingTalk window attached.";

    public MainWindowViewModel(
        WindowSupervisor windowSupervisor,
        UiaMessageProbeCoordinator messageProbeCoordinator,
        ScreenshotOcrCapturePipeline screenshotOcrCapturePipeline,
        EventNormalizer eventNormalizer,
        RawEventsRepository rawEventsRepository,
        ConversationTriggerSnapshotsRepository conversationTriggerSnapshotsRepository,
        HostControlState controlState,
        HostRuntimeStatus runtimeStatus,
        IStructuredSourceProbe structuredSourceProbe,
        IUiaConversationDiagnosticsProvider conversationDiagnosticsProvider,
        IWindowDiagnosticsProvider windowDiagnosticsProvider,
        IDingTalkLauncher dingTalkLauncher,
        IDingTalkWindowRestorer dingTalkWindowRestorer)
    {
        ArgumentNullException.ThrowIfNull(windowSupervisor);
        ArgumentNullException.ThrowIfNull(messageProbeCoordinator);
        ArgumentNullException.ThrowIfNull(screenshotOcrCapturePipeline);
        ArgumentNullException.ThrowIfNull(eventNormalizer);
        ArgumentNullException.ThrowIfNull(rawEventsRepository);
        ArgumentNullException.ThrowIfNull(conversationTriggerSnapshotsRepository);
        ArgumentNullException.ThrowIfNull(controlState);
        ArgumentNullException.ThrowIfNull(runtimeStatus);
        ArgumentNullException.ThrowIfNull(structuredSourceProbe);
        ArgumentNullException.ThrowIfNull(conversationDiagnosticsProvider);
        ArgumentNullException.ThrowIfNull(windowDiagnosticsProvider);
        ArgumentNullException.ThrowIfNull(dingTalkLauncher);
        ArgumentNullException.ThrowIfNull(dingTalkWindowRestorer);

        _windowSupervisor = windowSupervisor;
        _messageProbeCoordinator = messageProbeCoordinator;
        _screenshotOcrCapturePipeline = screenshotOcrCapturePipeline;
        _eventNormalizer = eventNormalizer;
        _rawEventsRepository = rawEventsRepository;
        _conversationTriggerSnapshotsRepository = conversationTriggerSnapshotsRepository;
        _controlState = controlState;
        _runtimeStatus = runtimeStatus;
        _structuredSourceProbe = structuredSourceProbe;
        _conversationDiagnosticsProvider = conversationDiagnosticsProvider;
        _windowDiagnosticsProvider = windowDiagnosticsProvider;
        _dingTalkLauncher = dingTalkLauncher;
        _dingTalkWindowRestorer = dingTalkWindowRestorer;
        _controlState.ActionRequested += OnControlActionRequested;
        StartCommand = new DelegateCommand(Start);
        StopCommand = new DelegateCommand(Stop);
        ReloadCommand = new DelegateCommand(Reload);
        ReattachCommand = new DelegateCommand(Reattach);
        LaunchDingTalkCommand = new DelegateCommand(LaunchDingTalk);
        RestoreDingTalkWindowCommand = new DelegateCommand(RestoreDingTalkWindow);

        _supervisorTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromSeconds(1),
        };

        _supervisorTimer.Tick += OnSupervisorTick;
        _supervisorTimer.Start();
        ApplySnapshot(_windowSupervisor.LastSnapshot);
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public ICommand StartCommand { get; }

    public ICommand StopCommand { get; }

    public ICommand ReloadCommand { get; }

    public ICommand ReattachCommand { get; }

    public ICommand LaunchDingTalkCommand { get; }

    public ICommand RestoreDingTalkWindowCommand { get; }

    public double HostedSurfaceWidth => 1024;

    public double HostedSurfaceHeight => 720;

    public string StatusText
    {
        get => _statusText;
        private set => SetProperty(ref _statusText, value);
    }

    public string SurfaceStatusText
    {
        get => _surfaceStatusText;
        private set => SetProperty(ref _surfaceStatusText, value);
    }

    public string ShellStateText
    {
        get => _shellStateText;
        private set => SetProperty(ref _shellStateText, value);
    }

    public string CurrentHwndText
    {
        get => _currentHwndText;
        private set => SetProperty(ref _currentHwndText, value);
    }

    public string LastEventTimeText
    {
        get => _lastEventTimeText;
        private set => SetProperty(ref _lastEventTimeText, value);
    }

    public string StructuredSourcesText
    {
        get => _structuredSourcesText;
        private set => SetProperty(ref _structuredSourcesText, value);
    }

    public string WindowDiagnosticsText
    {
        get => _windowDiagnosticsText;
        private set => SetProperty(ref _windowDiagnosticsText, value);
    }

    public string LauncherStatusText
    {
        get => _launcherStatusText;
        private set => SetProperty(ref _launcherStatusText, value);
    }

    public string ConversationDiagnosticsText
    {
        get => _conversationDiagnosticsText;
        private set => SetProperty(ref _conversationDiagnosticsText, value);
    }

    public string LatestCaptureText
    {
        get
        {
            if (_lastObservedEvent is null)
            {
                return "No captured message yet.";
            }

            return _lastObservedEvent.SourceConversationName
                + " / "
                + _lastObservedEvent.SenderName
                + ": "
                + _lastObservedEvent.Text;
        }
    }

    public void Dispose()
    {
        _supervisorTimer.Tick -= OnSupervisorTick;
        _supervisorTimer.Stop();
        _controlState.ActionRequested -= OnControlActionRequested;
        _windowSupervisor.RequestStop();
        ApplySnapshot(_windowSupervisor.Tick(_hostSurfaceHandle, _hostSurfaceBounds));
    }

    public void UpdateHostSurface(IntPtr hostSurfaceHandle, int width, int height, bool isMinimized = false)
    {
        if (!ShouldUseHostSurface(isMinimized, width, height))
        {
            PauseHostSurface();
            return;
        }

        _hostSurfacePaused = false;
        _hostSurfaceHandle = hostSurfaceHandle;
        _hostSurfaceBounds = new HostSurfaceBounds(width, height).Normalize();
        ApplySnapshot(_windowSupervisor.Tick(_hostSurfaceHandle, _hostSurfaceBounds));
    }

    private void OnSupervisorTick(object? sender, EventArgs e)
    {
        if (_hostSurfacePaused)
        {
            PauseHostSurface();
            return;
        }

        var snapshot = _windowSupervisor.Tick(_hostSurfaceHandle, _hostSurfaceBounds);
        ApplySnapshot(snapshot);
        RefreshStructuredSourcesIfNeeded();
        TryCaptureLatestMessage(snapshot);
    }

    private void Start()
    {
        _controlState.Start();
    }

    private void Stop()
    {
        _controlState.Stop();
    }

    private void Reload()
    {
        _controlState.Reload();
    }

    private void Reattach()
    {
        if (_hostSurfacePaused)
        {
            PauseHostSurface();
            return;
        }

        _windowSupervisor.RequestReattach();
        ApplySnapshot(_windowSupervisor.Tick(_hostSurfaceHandle, _hostSurfaceBounds));
    }

    private void LaunchDingTalk()
    {
        var result = _dingTalkLauncher.Launch();
        LauncherStatusText = result.Status
            + ": "
            + result.Message
            + (string.IsNullOrWhiteSpace(result.LauncherPath) ? string.Empty : " (" + result.LauncherPath + ")");
    }

    private void RestoreDingTalkWindow()
    {
        var result = _dingTalkWindowRestorer.Restore();
        LauncherStatusText = result.Status
            + ": "
            + result.Message
            + (string.IsNullOrWhiteSpace(result.TargetHwnd) ? string.Empty : " (" + result.TargetHwnd + ")");
    }

    private void OnControlActionRequested(object? sender, HostControlAction action)
    {
        _supervisorTimer.Dispatcher.Invoke(() =>
        {
            switch (action)
            {
                case HostControlAction.Start:
                    _windowSupervisor.RequestStart();
                    break;
                case HostControlAction.Stop:
                    _windowSupervisor.RequestStop();
                    break;
                case HostControlAction.Reload:
                    _windowSupervisor.RequestReload();
                    break;
                default:
                    throw new ArgumentOutOfRangeException(nameof(action), action, "Unsupported control action.");
            }

            ApplySnapshot(_windowSupervisor.Tick(_hostSurfaceHandle, _hostSurfaceBounds));
        });
    }

    private void ApplySnapshot(WindowSupervisorSnapshot snapshot)
    {
        _runtimeStatus.UpdateWindowSnapshot(
            snapshot.ShellState.ToString(),
            snapshot.CurrentHwnd,
            snapshot.LastEventAt,
            snapshot.Message);
        ShellStateText = snapshot.ShellState.ToString();
        CurrentHwndText = snapshot.CurrentHwnd == IntPtr.Zero
            ? "n/a"
            : "0x" + snapshot.CurrentHwnd.ToInt64().ToString("X");
        LastEventTimeText = snapshot.LastEventAt == DateTimeOffset.MinValue
            ? "n/a"
            : snapshot.LastEventAt.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss");
        StatusText = snapshot.Message;
        SurfaceStatusText = snapshot.CurrentHwnd == IntPtr.Zero
            ? "No DingTalk window attached."
            : "Attached to " + CurrentHwndText + ".";
    }

    private void PauseHostSurface()
    {
        _hostSurfacePaused = true;
        ApplySnapshot(new WindowSupervisorSnapshot(
            WindowSupervisorShellState.AwaitingHostSurface,
            WindowSupervisorAction.None,
            IntPtr.Zero,
            _windowSupervisor.LastSnapshot.LastEventAt,
            "Host surface paused while the shell window is minimized or has no size."));
    }

    private void TryCaptureLatestMessage(WindowSupervisorSnapshot snapshot)
    {
        var now = DateTimeOffset.UtcNow;
        if (!ShouldAttemptCapture(
                _hostSurfacePaused,
                snapshot.ShellState,
                snapshot.CurrentHwnd,
                now,
                _lastCaptureAttemptAt,
                CapturePollInterval))
        {
            return;
        }

        _lastCaptureAttemptAt = now;

        try
        {
            var readiness = ProbeConversationReadiness(snapshot.CurrentHwnd);
            if (ShouldPauseCapture(readiness))
            {
                StatusText = "Capture paused: " + readiness;
                return;
            }

            var extracted = _messageProbeCoordinator.ProbeLatest();
            if (extracted is null)
            {
                QueueScreenshotFallback(snapshot.CurrentHwnd);
                return;
            }

            var normalized = _eventNormalizer.Normalize(extracted);
            if (normalized is null)
            {
                return;
            }

            StoreObservedEvent(normalized);
        }
        catch (Exception ex) when (ex is InvalidOperationException
            or System.Runtime.InteropServices.COMException
            or TimeoutException)
        {
            StatusText = "UIA capture failed: " + ex.Message;
        }
    }

    private ConversationReadiness ProbeConversationReadiness(IntPtr currentHwnd)
    {
        var diagnostics = _conversationDiagnosticsProvider.GetDiagnostics(currentHwnd, limit: 20);
        _runtimeStatus.UpdateConversationDiagnostics(diagnostics);
        _conversationTriggerSnapshotsRepository.AddIfChangedAsync(
                diagnostics,
                CancellationToken.None)
            .GetAwaiter()
            .GetResult();
        ConversationDiagnosticsText = StructuredSourceDisplayFormatter.FormatConversationDiagnostics(diagnostics);
        return ConversationReadinessEvaluator.Evaluate(diagnostics);
    }

    internal static bool ShouldPauseCapture(ConversationReadiness readiness)
    {
        return readiness is ConversationReadiness.BlockedByDialog
            or ConversationReadiness.BlockedByOverlay
            or ConversationReadiness.LoginRequired
            or ConversationReadiness.NoConversationList
            or ConversationReadiness.DiagnosticsError;
    }

    internal static bool ShouldQueueScreenshotFallback(bool ocrEnabled)
    {
        return ocrEnabled;
    }

    internal static bool ShouldUseHostSurface(bool isMinimized, int width, int height)
    {
        return !isMinimized && width > 0 && height > 0;
    }

    internal static bool ShouldAttemptCapture(
        bool hostSurfacePaused,
        WindowSupervisorShellState shellState,
        IntPtr currentHwnd,
        DateTimeOffset now,
        DateTimeOffset lastCaptureAttemptAt,
        TimeSpan pollInterval)
    {
        return !hostSurfacePaused
            && shellState == WindowSupervisorShellState.Attached
            && currentHwnd != IntPtr.Zero
            && now - lastCaptureAttemptAt >= pollInterval;
    }

    private void RefreshStructuredSourcesIfNeeded()
    {
        if (DateTimeOffset.UtcNow - _lastStructuredSourceRefreshAt < StructuredSourceRefreshInterval)
        {
            return;
        }

        _lastStructuredSourceRefreshAt = DateTimeOffset.UtcNow;
        try
        {
            StructuredSourcesText = StructuredSourceDisplayFormatter.FormatSummary(
                _structuredSourceProbe.Probe());
            WindowDiagnosticsText = StructuredSourceDisplayFormatter.FormatWindowDiagnostics(
                _windowDiagnosticsProvider.GetCandidateDiagnostics(limit: 12));
            LauncherStatusText = StructuredSourceDisplayFormatter.FormatLauncherDiagnostics(
                _dingTalkLauncher.GetDiagnostics());
            var conversationDiagnostics = _conversationDiagnosticsProvider.GetDiagnostics(_hostSurfaceHandle, limit: 20);
            _runtimeStatus.UpdateConversationDiagnostics(conversationDiagnostics);
            _conversationTriggerSnapshotsRepository.AddIfChangedAsync(
                    conversationDiagnostics,
                    CancellationToken.None)
                .GetAwaiter()
                .GetResult();
            ConversationDiagnosticsText = StructuredSourceDisplayFormatter.FormatConversationDiagnostics(
                conversationDiagnostics);
        }
        catch (Exception ex) when (ex is InvalidOperationException
            or HttpRequestException
            or System.Runtime.InteropServices.COMException
            or TimeoutException)
        {
            StructuredSourcesText = "Structured source probe failed: " + ex.Message;
            WindowDiagnosticsText = "Window diagnostics failed: " + ex.Message;
            ConversationDiagnosticsText = "Conversation diagnostics failed: " + ex.Message;
        }
    }

    private void QueueScreenshotFallback(IntPtr currentHwnd)
    {
        if (!ShouldQueueScreenshotFallback(_screenshotOcrCapturePipeline.IsEnabled))
        {
            return;
        }

        var now = DateTimeOffset.UtcNow;
        lock (_captureGate)
        {
            if (_screenshotFallbackInFlight
                || now - _lastScreenshotFallbackAttemptAt < CapturePollInterval)
            {
                return;
            }

            _screenshotFallbackInFlight = true;
            _lastScreenshotFallbackAttemptAt = now;
        }

        _ = Task.Run(async () =>
        {
            try
            {
                var normalized = await CaptureScreenshotFallbackAsync(currentHwnd, CancellationToken.None);
                if (normalized is not null)
                {
                    StoreObservedEvent(normalized);
                }
            }
            catch (Exception ex) when (ex is InvalidOperationException or System.Runtime.InteropServices.COMException)
            {
                SetStatusFromAnyThread("Screenshot fallback failed: " + ex.Message);
            }
            finally
            {
                lock (_captureGate)
                {
                    _screenshotFallbackInFlight = false;
                }
            }
        });
    }

    private async Task<DingTalkObservedEvent?> CaptureScreenshotFallbackAsync(
        IntPtr currentHwnd,
        CancellationToken cancellationToken)
    {
        var ocrEvent = await CaptureScreenshotOcrAsync(currentHwnd, cancellationToken);
        if (ocrEvent is not null)
        {
            return ocrEvent;
        }

        return null;
    }

    private Task<DingTalkObservedEvent?> CaptureScreenshotOcrAsync(
        IntPtr currentHwnd,
        CancellationToken cancellationToken)
    {
        if (!_screenshotOcrCapturePipeline.IsEnabled)
        {
            return Task.FromResult<DingTalkObservedEvent?>(null);
        }

        return _screenshotOcrCapturePipeline.CaptureAsync(currentHwnd, cancellationToken);
    }

    private void StoreObservedEvent(DingTalkObservedEvent normalized)
    {
        lock (_captureGate)
        {
            if (_lastObservedEvent?.EventId == normalized.EventId)
            {
                return;
            }

            _lastObservedEvent = normalized;
        }

        _rawEventsRepository.UpsertAsync(normalized, CancellationToken.None)
            .GetAwaiter()
            .GetResult();
        NotifyLatestCaptureChangedFromAnyThread();
    }

    private void NotifyLatestCaptureChangedFromAnyThread()
    {
        if (_supervisorTimer.Dispatcher.CheckAccess())
        {
            OnPropertyChanged(nameof(LatestCaptureText));
            return;
        }

        _supervisorTimer.Dispatcher.BeginInvoke(
            new Action(() => OnPropertyChanged(nameof(LatestCaptureText))));
    }

    private void SetStatusFromAnyThread(string status)
    {
        if (_supervisorTimer.Dispatcher.CheckAccess())
        {
            StatusText = status;
            return;
        }

        _supervisorTimer.Dispatcher.BeginInvoke(new Action(() => StatusText = status));
    }

    private void SetProperty<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (Equals(field, value))
        {
            return;
        }

        field = value;
        OnPropertyChanged(propertyName);
    }

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }

    private sealed class DelegateCommand : ICommand
    {
        private readonly Action _execute;

        public DelegateCommand(Action execute)
        {
            ArgumentNullException.ThrowIfNull(execute);
            _execute = execute;
        }

        public event EventHandler? CanExecuteChanged
        {
            add
            {
            }
            remove
            {
            }
        }

        public bool CanExecute(object? parameter)
        {
            return true;
        }

        public void Execute(object? parameter)
        {
            _execute();
        }
    }
}
