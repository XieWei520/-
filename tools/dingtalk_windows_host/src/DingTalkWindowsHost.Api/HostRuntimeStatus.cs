using DingTalkWindowsHost.Contracts.Models;

namespace DingTalkWindowsHost.Api;

public sealed class HostRuntimeStatus
{
    private readonly object _gate = new();
    private readonly Func<bool> _ocrEnabledSource;
    private string _shellState = "Stopped";
    private IntPtr _currentHwnd;
    private DateTimeOffset _lastEventAt = DateTimeOffset.MinValue;
    private string _message = "Host shell is idle.";
    private ConversationReadiness _conversationReadiness = ConversationReadiness.NoConversationList;
    private string _conversationReadinessMessage = "Conversation diagnostics have not run yet.";

    public HostRuntimeStatus()
        : this(static () => false)
    {
    }

    public HostRuntimeStatus(Func<bool> ocrEnabledSource)
    {
        ArgumentNullException.ThrowIfNull(ocrEnabledSource);
        _ocrEnabledSource = ocrEnabledSource;
    }

    public void UpdateWindowSnapshot(
        string shellState,
        IntPtr currentHwnd,
        DateTimeOffset lastEventAt,
        string message)
    {
        lock (_gate)
        {
            _shellState = shellState;
            _currentHwnd = currentHwnd;
            _lastEventAt = lastEventAt;
            _message = message;
        }
    }

    public LoopbackStatusDto ToDto(bool captureRunning)
    {
        string shellState;
        IntPtr currentHwnd;
        DateTimeOffset lastEventAt;
        string message;
        ConversationReadiness conversationReadiness;
        string conversationReadinessMessage;
        lock (_gate)
        {
            shellState = _shellState;
            currentHwnd = _currentHwnd;
            lastEventAt = _lastEventAt;
            message = _message;
            conversationReadiness = _conversationReadiness;
            conversationReadinessMessage = _conversationReadinessMessage;
        }

        return new LoopbackStatusDto(
            CaptureRunning: captureRunning,
            ServerTime: DateTimeOffset.UtcNow,
            Version: "m1",
            ShellState: shellState,
            CurrentHwnd: FormatHandle(currentHwnd),
            Message: message,
            LastWindowEventAt: lastEventAt == DateTimeOffset.MinValue ? null : lastEventAt,
            OcrEnabled: _ocrEnabledSource(),
            ConversationReadiness: conversationReadiness.ToString(),
            ConversationReadinessMessage: conversationReadinessMessage);
    }

    public void UpdateConversationDiagnostics(UiaConversationDiagnosticsResult diagnostics)
    {
        ArgumentNullException.ThrowIfNull(diagnostics);

        lock (_gate)
        {
            _conversationReadiness = ConversationReadinessEvaluator.Evaluate(diagnostics);
            _conversationReadinessMessage = ConversationReadinessEvaluator.BuildMessage(diagnostics);
        }
    }

    public IntPtr GetCurrentHwnd()
    {
        lock (_gate)
        {
            return _currentHwnd;
        }
    }

    private static string FormatHandle(IntPtr handle)
    {
        return handle == IntPtr.Zero ? string.Empty : "0x" + handle.ToInt64().ToString("X");
    }
}
