using System.Text.Json.Serialization;

namespace DingTalkWindowsHost.Contracts.Models;

public enum CaptureSource
{
    UiaText,
    UiaImageMetadata,
    PreviewSave,
    ChatAreaScreenshot,
    ChatAreaScreenshotOcr,
}

public sealed record DingTalkObservedEvent(
    string EventId,
    string SourceConversationId,
    string SourceConversationName,
    string EmbeddedSourceName,
    string SenderName,
    DateTimeOffset ObservedAt,
    string Text,
    string LocalImagePath,
    CaptureSource CaptureSource,
    string ContentHash);

public sealed record WindowScreenshotResult(
    string LocalImagePath,
    string Sha256,
    int Width,
    int Height,
    long BytesWritten,
    DateTimeOffset CapturedAt);

public enum StructuredSourceKind
{
    UiAutomation,
    EmbeddedChromium,
    BrowserDevTools,
    NetworkCapture,
    LocalCacheOrLog,
    ScreenshotOcr,
}

public enum StructuredSourceStatus
{
    Candidate,
    NeedsProbe,
    NeedsManualApproval,
    FallbackOnly,
    Unavailable,
}

public sealed record StructuredSourceProbeSignal(
    StructuredSourceKind Kind,
    StructuredSourceStatus Status,
    int EstimatedLatencyMs,
    string Evidence,
    string NextAction);

public sealed record StructuredSourceProbeResult(
    DateTimeOffset ObservedAt,
    string Recommendation,
    IReadOnlyList<StructuredSourceProbeSignal> Signals);

public sealed record DevToolsTargetMetadata(
    string Id,
    string Type,
    string Title,
    string Url,
    bool HasWebSocketDebuggerUrl);

public sealed record DevToolsTargetDiagnosticsResult(
    DateTimeOffset ObservedAt,
    StructuredSourceStatus Status,
    int Port,
    int OwnerProcessId,
    string Recommendation,
    IReadOnlyList<DevToolsTargetMetadata> Targets);

[JsonConverter(typeof(JsonStringEnumConverter<LocalStructuredSourceCandidateKind>))]
public enum LocalStructuredSourceCandidateKind
{
    SqliteDatabase,
    SqliteWriteAheadLog,
    LevelDbStore,
    LogFile,
    JsonFile,
    MediaCache,
    Unknown,
}

public sealed record LocalStructuredSourceCandidate(
    LocalStructuredSourceCandidateKind Kind,
    string PathHint,
    long SizeBytes,
    DateTimeOffset LastWriteTime,
    string Evidence);

public sealed record LocalStructuredSourceDiagnosticsResult(
    DateTimeOffset ObservedAt,
    StructuredSourceStatus Status,
    int CandidateCount,
    string Recommendation,
    IReadOnlyList<LocalStructuredSourceCandidate> Candidates);

[JsonConverter(typeof(JsonStringEnumConverter<LocalStructuredSourceChangeKind>))]
public enum LocalStructuredSourceChangeKind
{
    Baseline,
    Added,
    Modified,
    Unchanged,
}

public sealed record LocalStructuredSourceChange(
    LocalStructuredSourceCandidateKind Kind,
    LocalStructuredSourceChangeKind ChangeKind,
    string PathHash,
    long SizeBytes,
    DateTimeOffset LastWriteTime,
    long PreviousSizeBytes,
    DateTimeOffset? PreviousLastWriteTime,
    string RelatedPathHash = "",
    string RelatedHeaderKind = "");

public sealed record LocalStructuredSourceChangeDiagnosticsResult(
    DateTimeOffset ObservedAt,
    StructuredSourceStatus Status,
    int CandidateCount,
    int ChangedCount,
    string Recommendation,
    IReadOnlyList<LocalStructuredSourceChange> Changes);

[JsonConverter(typeof(JsonStringEnumConverter<LocalStructuredSourceInspectionStatus>))]
public enum LocalStructuredSourceInspectionStatus
{
    Inspected,
    Skipped,
    Failed,
}

[JsonConverter(typeof(JsonStringEnumConverter<LocalStructuredSourceStructureKind>))]
public enum LocalStructuredSourceStructureKind
{
    SqliteTable,
    JsonObject,
    JsonArray,
    LevelDbFileGroup,
}

public sealed record LocalStructuredSourceStructureItem(
    LocalStructuredSourceStructureKind Kind,
    string Name,
    IReadOnlyList<string> ChildNames,
    string Evidence);

public sealed record LocalStructuredSourceInspection(
    LocalStructuredSourceCandidateKind Kind,
    LocalStructuredSourceInspectionStatus Status,
    string PathHint,
    string Evidence,
    IReadOnlyList<LocalStructuredSourceStructureItem> StructureItems);

public sealed record LocalStructuredSourceInspectionDiagnosticsResult(
    DateTimeOffset ObservedAt,
    StructuredSourceStatus Status,
    int InspectedCount,
    string Recommendation,
    IReadOnlyList<LocalStructuredSourceInspection> Inspections);

[JsonConverter(typeof(JsonStringEnumConverter<LocalStructuredContentShapeStatus>))]
public enum LocalStructuredContentShapeStatus
{
    Candidate,
    KeywordOnly,
    NoMessageShape,
    NotReadable,
    Skipped,
    Failed,
}

[JsonConverter(typeof(JsonStringEnumConverter<LocalStructuredContentFieldRole>))]
public enum LocalStructuredContentFieldRole
{
    Unknown,
    Conversation,
    Sender,
    Text,
    Timestamp,
    MessageId,
}

public sealed record LocalStructuredContentFieldShape(
    string Name,
    LocalStructuredContentFieldRole Role,
    int NonEmptySampleCount,
    int MinLength,
    int MaxLength,
    IReadOnlyList<string> SampleValueHashes);

public sealed record LocalStructuredContentTableShape(
    string Name,
    long RowCount,
    int Score,
    string Evidence,
    IReadOnlyList<LocalStructuredContentFieldShape> Fields);

public sealed record LocalStructuredContentKeywordHit(
    string Keyword,
    int Count);

public sealed record LocalStructuredContentShape(
    LocalStructuredSourceCandidateKind Kind,
    LocalStructuredContentShapeStatus Status,
    string PathHash,
    string PathHint,
    string Evidence,
    IReadOnlyList<LocalStructuredContentTableShape> Tables,
    IReadOnlyList<LocalStructuredContentKeywordHit> KeywordHits);

public sealed record LocalStructuredContentShapeDiagnosticsResult(
    DateTimeOffset ObservedAt,
    StructuredSourceStatus Status,
    int ShapeCount,
    string Recommendation,
    IReadOnlyList<LocalStructuredContentShape> Shapes);

public sealed record UiaConversationItem(
    string AutomationId,
    string Name,
    bool IsSelected,
    bool HasUnreadHint);

public sealed record UiaBlockingDialog(
    string Title,
    string Message,
    string ClassName);

public sealed record UiaConversationDiagnosticsResult(
    DateTimeOffset ObservedAt,
    IReadOnlyList<UiaConversationItem> Conversations,
    IReadOnlyList<UiaBlockingDialog> BlockingDialogs,
    string Recommendation,
    bool MessageSurfaceVisible = false);

public sealed record UiaCandidateProbe(
    string Hwnd,
    string Title,
    string ClassName,
    string ProcessName,
    bool IsHosted,
    bool IsSelectedWindowCandidate,
    bool IsVisible,
    bool IsTopLevel,
    int Width,
    int Height,
    ConversationReadiness Readiness,
    int ConversationCount,
    int BlockingDialogCount,
    string Recommendation,
    IReadOnlyList<string> NodeSummary,
    string Error);

public sealed record UiaCandidateDiagnosticsResult(
    DateTimeOffset ObservedAt,
    string Recommendation,
    string HostedHwnd,
    string SelectedWindowCandidateHwnd,
    int TotalCandidates,
    IReadOnlyList<UiaCandidateProbe> Probes);

[JsonConverter(typeof(JsonStringEnumConverter<UiaTextCandidateSource>))]
public enum UiaTextCandidateSource
{
    RootSnapshot,
    MessageSurfaceSnapshot,
}

public sealed record UiaTextCandidate(
    UiaTextCandidateSource Source,
    string AutomationIdHash,
    string NameHash,
    int NameLength,
    string ControlType,
    string ClassName,
    string ClassNameHash,
    bool IsPotentialMessageText,
    bool IsLikelyNoise);

public sealed record UiaTextCandidateWindow(
    string Hwnd,
    string ClassName,
    string ProcessName,
    bool IsHosted,
    bool IsVisible,
    bool IsTopLevel,
    int Width,
    int Height,
    int TextCandidateCount,
    int PotentialMessageTextCount,
    IReadOnlyList<UiaTextCandidate> TextCandidates,
    string Error);

public sealed record UiaTextCandidateDiagnosticsResult(
    DateTimeOffset ObservedAt,
    StructuredSourceStatus Status,
    string Recommendation,
    string HostedHwnd,
    int TotalWindowCandidates,
    IReadOnlyList<UiaTextCandidateWindow> Windows);

public sealed record ClipboardMessageProbeDiagnosticsResult(
    DateTimeOffset ObservedAt,
    bool Enabled,
    string TargetHwnd,
    string Status,
    bool ClipboardChanged,
    int CopiedTextLength,
    string CopiedTextHash,
    int ExtractedTextLength,
    string ExtractedTextHash,
    string SourceConversationIdHint,
    string Error);

[JsonConverter(typeof(JsonStringEnumConverter<WindowCandidateHealth>))]
public enum WindowCandidateHealth
{
    Ready,
    NoDingTalkProcess,
    NoEligibleWindow,
    HiddenWorkspaceOnly,
    BlockedByDialog,
    HostedCandidate,
}

[JsonConverter(typeof(JsonStringEnumConverter<WindowCandidateAttachmentDecision>))]
public enum WindowCandidateAttachmentDecision
{
    Selected,
    Candidate,
    Rejected,
}

[JsonConverter(typeof(JsonStringEnumConverter<WindowCandidateRejectionReason>))]
public enum WindowCandidateRejectionReason
{
    None,
    ZeroHandle,
    Disabled,
    ToolWindow,
    NotTopLevel,
    Hidden,
    TooSmall,
    TransientOverlay,
    UnsupportedClass,
}

public sealed record WindowCandidateDiagnostic(
    string Hwnd,
    bool IsSelected,
    WindowCandidateAttachmentDecision Decision,
    WindowCandidateRejectionReason RejectionReason,
    string Title,
    string ClassName,
    string ProcessName,
    bool IsVisible,
    bool IsEnabled,
    bool IsTopLevel,
    bool IsToolWindow,
    int Width,
    int Height,
    int ZOrder);

public sealed record WindowCandidateDiagnosticsResult(
    DateTimeOffset ObservedAt,
    WindowCandidateHealth Health,
    string SelectedHwnd,
    string Recommendation,
    int TotalDingTalkCandidates,
    int VisibleCandidates,
    int HiddenWorkspaceCandidates,
    int BlockingDialogCandidates,
    IReadOnlyList<string> RawSummaries,
    IReadOnlyDictionary<WindowCandidateRejectionReason, int> RejectionReasonCounts,
    IReadOnlyList<WindowCandidateDiagnostic> Candidates);

[JsonConverter(typeof(JsonStringEnumConverter<DingTalkLaunchStatus>))]
public enum DingTalkLaunchStatus
{
    Started,
    NotConfigured,
    NotFound,
    Failed,
}

public sealed record DingTalkLaunchResult(
    DingTalkLaunchStatus Status,
    string Message,
    string LauncherPath,
    DateTimeOffset AttemptedAt);

[JsonConverter(typeof(JsonStringEnumConverter<DingTalkLauncherReadiness>))]
public enum DingTalkLauncherReadiness
{
    Ready,
    NotConfigured,
    NotFound,
}

public sealed record DingTalkLauncherDiagnosticsResult(
    DingTalkLauncherReadiness Readiness,
    bool IsConfigured,
    bool PathExists,
    int RemoteDebuggingPort,
    bool RendererAccessibilityEnabled,
    string LauncherPath,
    string Recommendation,
    DateTimeOffset ObservedAt);

[JsonConverter(typeof(JsonStringEnumConverter<DingTalkWindowRestoreStatus>))]
public enum DingTalkWindowRestoreStatus
{
    Restored,
    NoCandidate,
    Failed,
}

public sealed record DingTalkWindowRestoreResult(
    DingTalkWindowRestoreStatus Status,
    string TargetHwnd,
    string Message,
    DateTimeOffset AttemptedAt);

[JsonConverter(typeof(JsonStringEnumConverter<DingTalkNavigationStatus>))]
public enum DingTalkNavigationStatus
{
    Activated,
    NoWindow,
    TargetNotFound,
    Closed,
    NotPresent,
    Failed,
}

public sealed record DingTalkNavigationResult(
    DingTalkNavigationStatus Status,
    string TargetHwnd,
    string TargetAutomationId,
    string Message,
    DateTimeOffset AttemptedAt);

[JsonConverter(typeof(JsonStringEnumConverter<ConversationReadiness>))]
public enum ConversationReadiness
{
    Ready,
    BlockedByDialog,
    LoginRequired,
    NoConversationList,
    ConversationListVisible,
    DiagnosticsError,
    BlockedByOverlay,
}

public sealed record ConversationTriggerSnapshot(
    string SnapshotId,
    DateTimeOffset ObservedAt,
    ConversationReadiness Readiness,
    int ConversationCount,
    int UnreadCount,
    string SelectedConversationName,
    string FirstUnreadConversationName,
    string ContentHash,
    string Summary);

public static class ConversationReadinessEvaluator
{
    public static ConversationReadiness Evaluate(UiaConversationDiagnosticsResult diagnostics)
    {
        ArgumentNullException.ThrowIfNull(diagnostics);

        if (diagnostics.BlockingDialogs.Count > 0)
        {
            return ConversationReadiness.BlockedByDialog;
        }

        if (diagnostics.Recommendation.Contains("conversation-diagnostics-error", StringComparison.OrdinalIgnoreCase))
        {
            return ConversationReadiness.DiagnosticsError;
        }

        if (diagnostics.Recommendation.Contains("blocked-by-overlay", StringComparison.OrdinalIgnoreCase))
        {
            return ConversationReadiness.BlockedByOverlay;
        }

        if (diagnostics.Recommendation.Contains("login-required", StringComparison.OrdinalIgnoreCase))
        {
            return ConversationReadiness.LoginRequired;
        }

        if (diagnostics.Conversations.Count == 0)
        {
            return ConversationReadiness.NoConversationList;
        }

        return diagnostics.MessageSurfaceVisible
            || diagnostics.Conversations.Any(static conversation => conversation.IsSelected)
            ? ConversationReadiness.Ready
            : ConversationReadiness.ConversationListVisible;
    }

    public static string BuildMessage(UiaConversationDiagnosticsResult diagnostics)
    {
        ArgumentNullException.ThrowIfNull(diagnostics);

        var readiness = Evaluate(diagnostics);
        return readiness switch
        {
            ConversationReadiness.BlockedByDialog => "Blocked by dialog: "
                + (diagnostics.BlockingDialogs[0].Message.Length == 0
                    ? diagnostics.BlockingDialogs[0].ClassName
                    : diagnostics.BlockingDialogs[0].Message),
            ConversationReadiness.BlockedByOverlay => diagnostics.Recommendation,
            ConversationReadiness.LoginRequired => diagnostics.Recommendation,
            ConversationReadiness.DiagnosticsError => diagnostics.Recommendation,
            ConversationReadiness.NoConversationList => "Conversation list is not visible through UIA.",
            ConversationReadiness.ConversationListVisible => "Conversation list is visible; no selected conversation detected.",
            ConversationReadiness.Ready => diagnostics.MessageSurfaceVisible
                ? "Conversation list is visible and the active message surface is present."
                : "Conversation list is visible and a selected conversation is present.",
            _ => "Unknown conversation readiness.",
        };
    }
}
