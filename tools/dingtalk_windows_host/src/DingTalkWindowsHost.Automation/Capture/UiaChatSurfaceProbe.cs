using FlaUI.Core.AutomationElements;
using FlaUI.Core.Definitions;
using FlaUI.UIA3;
using DingTalkWindowsHost.Contracts.Models;

namespace DingTalkWindowsHost.Automation.Capture;

public sealed class UiaChatSurfaceProbe
{
    private const int DefaultMaxNodes = 512;
    private const int DefaultMaxDepth = 8;
    private const int FocusedMessageSurfaceMaxNodes = 768;
    private const int FocusedMessageSurfaceMaxDepth = 10;
    private const int MaxPatternTextLength = 4096;
    private static readonly TimeSpan DefaultSnapshotBudget = TimeSpan.FromMilliseconds(800);
    private static readonly TimeSpan FocusedMessageSurfaceBudget = TimeSpan.FromMilliseconds(700);

    private readonly UiaMessageExtractor _extractor;
    private readonly int _maxNodes;
    private readonly int _maxDepth;
    private readonly TimeSpan _snapshotBudget;

    public UiaChatSurfaceProbe()
        : this(new UiaMessageExtractor(), DefaultMaxNodes)
    {
    }

    public UiaChatSurfaceProbe(UiaMessageExtractor extractor, int maxNodes)
        : this(extractor, maxNodes, DefaultMaxDepth, DefaultSnapshotBudget)
    {
    }

    public UiaChatSurfaceProbe(
        UiaMessageExtractor extractor,
        int maxNodes,
        int maxDepth,
        TimeSpan snapshotBudget)
    {
        ArgumentNullException.ThrowIfNull(extractor);

        _extractor = extractor;
        _maxNodes = Math.Max(1, maxNodes);
        _maxDepth = Math.Max(0, maxDepth);
        _snapshotBudget = snapshotBudget <= TimeSpan.Zero ? DefaultSnapshotBudget : snapshotBudget;
    }

    public ExtractedMessage? ProbeLatest(IntPtr windowHandle)
    {
        if (windowHandle == IntPtr.Zero)
        {
            return null;
        }

        using var automation = new UIA3Automation();
        ConfigureAutomationTimeouts(automation);
        var root = automation.FromHandle(windowHandle);
        var snapshot = SnapshotElementNodes(automation, root);
        var nodes = snapshot.Nodes.Select(static node => node.Node).ToArray();
        var extracted = _extractor.ExtractLatest(nodes);
        if (extracted is not null)
        {
            return extracted;
        }

        var focusedMessageSurfaceNodes = SnapshotFocusedMessageSurfaceNodes(automation, snapshot.Nodes);
        return focusedMessageSurfaceNodes.Count == 0
            ? null
            : _extractor.ExtractLatest(focusedMessageSurfaceNodes);
    }

    public IReadOnlyList<string> ProbeNodeSummary(IntPtr windowHandle, int maxNodes)
    {
        if (windowHandle == IntPtr.Zero)
        {
            return Array.Empty<string>();
        }

        using var automation = new UIA3Automation();
        ConfigureAutomationTimeouts(automation);
        var root = automation.FromHandle(windowHandle);
        var snapshot = SnapshotNodes(automation, root);
        var summary = SummarizeNodes(snapshot.Nodes, maxNodes).ToList();
        AddSnapshotWarning(summary, snapshot);
        return summary;
    }

    public IReadOnlyList<UiaNode> ProbeNodes(IntPtr windowHandle, int maxNodes)
    {
        if (windowHandle == IntPtr.Zero)
        {
            return Array.Empty<UiaNode>();
        }

        using var automation = new UIA3Automation();
        ConfigureAutomationTimeouts(automation);
        var root = automation.FromHandle(windowHandle);
        var snapshot = SnapshotNodes(automation, root);
        return snapshot.Nodes.Take(Math.Max(0, maxNodes)).ToArray();
    }

    public IReadOnlyList<string> ProbeMessageSurfaceNodeSummary(IntPtr windowHandle, int maxNodes)
    {
        if (windowHandle == IntPtr.Zero)
        {
            return Array.Empty<string>();
        }

        using var automation = new UIA3Automation();
        ConfigureAutomationTimeouts(automation);
        var root = automation.FromHandle(windowHandle);
        var rootSnapshot = SnapshotElementNodes(automation, root);
        var focusedSnapshot = SnapshotFocusedMessageSurface(
            automation,
            rootSnapshot.Nodes,
            Math.Max(FocusedMessageSurfaceMaxNodes, Math.Max(1, maxNodes)),
            FocusedMessageSurfaceMaxDepth,
            FocusedMessageSurfaceBudget);
        var summary = SummarizeNodes(
                focusedSnapshot.Nodes,
                maxNodes,
                includeHelpText: true)
            .ToList();

        if (focusedSnapshot.SurfaceCount == 0)
        {
            summary.Add("uia-message-surface-not-found");
        }

        foreach (var warning in focusedSnapshot.Warnings)
        {
            summary.Add(warning);
        }

        var rootSnapshotWarning = BuildElementSnapshotWarning(rootSnapshot);
        if (!string.IsNullOrWhiteSpace(rootSnapshotWarning))
        {
            summary.Add(rootSnapshotWarning);
        }

        return summary;
    }

    public IReadOnlyList<UiaNode> ProbeMessageSurfaceNodes(IntPtr windowHandle, int maxNodes)
    {
        if (windowHandle == IntPtr.Zero)
        {
            return Array.Empty<UiaNode>();
        }

        using var automation = new UIA3Automation();
        ConfigureAutomationTimeouts(automation);
        var root = automation.FromHandle(windowHandle);
        var rootSnapshot = SnapshotElementNodes(automation, root);
        var focusedSnapshot = SnapshotFocusedMessageSurface(
            automation,
            rootSnapshot.Nodes,
            Math.Max(1, maxNodes),
            FocusedMessageSurfaceMaxDepth,
            FocusedMessageSurfaceBudget);
        return focusedSnapshot.Nodes.Take(Math.Max(0, maxNodes)).ToArray();
    }

    public UiaConversationDiagnosticsResult ProbeConversationDiagnostics(IntPtr windowHandle, int limit)
    {
        if (windowHandle == IntPtr.Zero)
        {
            return UiaConversationDiagnosticsExtractor.Extract(Array.Empty<UiaNode>(), limit);
        }

        using var automation = new UIA3Automation();
        ConfigureAutomationTimeouts(automation);
        var root = automation.FromHandle(windowHandle);
        var snapshot = SnapshotNodes(automation, root);
        var diagnostics = UiaConversationDiagnosticsExtractor.Extract(snapshot.Nodes, limit);
        var warning = BuildSnapshotWarning(snapshot);
        return string.IsNullOrWhiteSpace(warning)
            ? diagnostics
            : diagnostics with { Recommendation = diagnostics.Recommendation + " " + warning };
    }

    public static IReadOnlyList<string> SummarizeNodes(
        IEnumerable<UiaNode> nodes,
        int maxNodes,
        bool includeHelpText = false)
    {
        ArgumentNullException.ThrowIfNull(nodes);

        return nodes
            .Take(Math.Max(0, maxNodes))
            .Select(node =>
                "automationId='"
                + node.AutomationId
                + "' name='"
                + node.Name
                + "' controlType='"
                + node.ControlType
                + "' class='"
                + node.ClassName
                + "'"
                + (includeHelpText
                    ? " helpText='" + node.HelpText + "'"
                    : string.Empty))
            .ToArray();
    }

    private BoundedUiaTreeSnapshot<UiaNode> SnapshotNodes(UIA3Automation automation, AutomationElement root)
    {
        var walker = automation.TreeWalkerFactory.GetControlViewWalker();
        return BoundedUiaTreeWalker.Walk(
            root,
            _maxNodes,
            _maxDepth,
            _snapshotBudget,
            ReadElementNode,
            element => ReadChildren(walker, element));
    }

    private BoundedUiaTreeSnapshot<ElementNode> SnapshotElementNodes(UIA3Automation automation, AutomationElement root)
    {
        var walker = automation.TreeWalkerFactory.GetControlViewWalker();
        return BoundedUiaTreeWalker.Walk(
            root,
            _maxNodes,
            _maxDepth,
            _snapshotBudget,
            static element => new ElementNode(element, ReadElementNode(element)),
            element => ReadChildren(walker, element));
    }

    private static IReadOnlyList<UiaNode> SnapshotFocusedMessageSurfaceNodes(
        UIA3Automation automation,
        IEnumerable<ElementNode> rootSnapshotNodes)
    {
        return SnapshotFocusedMessageSurface(
                automation,
                rootSnapshotNodes,
                FocusedMessageSurfaceMaxNodes,
                FocusedMessageSurfaceMaxDepth,
                FocusedMessageSurfaceBudget)
            .Nodes;
    }

    private static FocusedMessageSurfaceSnapshot SnapshotFocusedMessageSurface(
        UIA3Automation automation,
        IEnumerable<ElementNode> rootSnapshotNodes,
        int maxNodes,
        int maxDepth,
        TimeSpan budget)
    {
        // Message text in Qt/Chromium surfaces can be outside ControlView; keep RawView scoped to chat surfaces only.
        var walker = automation.TreeWalkerFactory.GetRawViewWalker();
        var nodes = new List<UiaNode>();
        var warnings = new List<string>();
        var surfaceCount = 0;
        foreach (var surface in SelectFocusedMessageSurfaceElements(rootSnapshotNodes).Take(4))
        {
            surfaceCount++;
            try
            {
                var remainingNodeBudget = Math.Max(1, maxNodes - nodes.Count);
                var snapshot = BoundedUiaTreeWalker.Walk(
                    surface.Element,
                    remainingNodeBudget,
                    maxDepth,
                    budget,
                    ReadElementNode,
                    element => ReadChildren(walker, element));
                nodes.AddRange(snapshot.Nodes);
                var warning = BuildSnapshotWarning(snapshot);
                if (!string.IsNullOrWhiteSpace(warning))
                {
                    warnings.Add("uia-message-surface-" + warning);
                }
            }
            catch (Exception ex) when (IsTransientUiaException(ex) || ex is InvalidOperationException)
            {
                warnings.Add("uia-message-surface-warning type='"
                    + ex.GetType().Name
                    + "' message='"
                    + ex.Message
                    + "'");
            }
        }

        return new FocusedMessageSurfaceSnapshot(nodes, surfaceCount, warnings);
    }

    private static IReadOnlyList<ElementNode> SelectFocusedMessageSurfaceElements(
        IEnumerable<ElementNode> rootSnapshotNodes)
    {
        var messageSurfaces = rootSnapshotNodes
            .Where(static elementNode => DingTalkMessageSurfaceDetector.IsMessageSurfaceNode(elementNode.Node))
            .ToArray();
        var chatBubbles = messageSurfaces
            .Where(static elementNode => DingTalkMessageSurfaceDetector.IsChatBubbleNode(elementNode.Node))
            .ToArray();

        return chatBubbles.Length > 0 ? chatBubbles : messageSurfaces;
    }

    private static UiaNode ReadElementNode(AutomationElement element)
    {
        try
        {
            var node = ReadNode(
                () => element.AutomationId,
                () => element.Name,
                () => element.ControlType.ToString(),
                () => element.ClassName,
                () => element.HelpText);
            if (!string.IsNullOrWhiteSpace(node.Name))
            {
                return node;
            }

            var patternText = TryReadPatternText(element);
            return string.IsNullOrWhiteSpace(patternText)
                ? node
                : node with { Name = patternText };
        }
        catch (Exception ex) when (IsTransientUiaException(ex))
        {
            return new UiaNode(
                AutomationId: string.Empty,
                Name: "uia-node-error type='" + ex.GetType().Name + "' message='" + ex.Message + "'",
                ControlType: "Error",
                ClassName: string.Empty);
        }
    }

    private static string TryReadPatternText(AutomationElement element)
    {
        var valueText = TryReadValuePatternText(element);
        if (!string.IsNullOrWhiteSpace(valueText))
        {
            return valueText;
        }

        var textPatternText = TryReadTextPatternText(element);
        if (!string.IsNullOrWhiteSpace(textPatternText))
        {
            return textPatternText;
        }

        var textChildPatternText = TryReadTextChildPatternText(element);
        if (!string.IsNullOrWhiteSpace(textChildPatternText))
        {
            return textChildPatternText;
        }

        return TryReadLegacyAccessibleText(element);
    }

    private static string TryReadValuePatternText(AutomationElement element)
    {
        try
        {
            return element.Patterns.Value.TryGetPattern(out var valuePattern)
                ? SafePatternString(valuePattern.Value)
                : string.Empty;
        }
        catch (Exception)
        {
            return string.Empty;
        }
    }

    private static string TryReadTextPatternText(AutomationElement element)
    {
        try
        {
            return element.Patterns.Text.TryGetPattern(out var textPattern)
                ? SafePatternString(textPattern.DocumentRange.GetText(MaxPatternTextLength))
                : string.Empty;
        }
        catch (Exception)
        {
            return string.Empty;
        }
    }

    private static string TryReadTextChildPatternText(AutomationElement element)
    {
        try
        {
            return element.Patterns.TextChild.TryGetPattern(out var textChildPattern)
                ? SafePatternString(textChildPattern.TextRange.GetText(MaxPatternTextLength))
                : string.Empty;
        }
        catch (Exception)
        {
            return string.Empty;
        }
    }

    private static string TryReadLegacyAccessibleText(AutomationElement element)
    {
        try
        {
            if (!element.Patterns.LegacyIAccessible.TryGetPattern(out var legacyPattern))
            {
                return string.Empty;
            }

            return FirstNonEmptyPatternString(
                legacyPattern.Name,
                legacyPattern.Value,
                legacyPattern.Description);
        }
        catch (Exception)
        {
            return string.Empty;
        }
    }

    private static string FirstNonEmptyPatternString(params object?[] values)
    {
        foreach (var value in values)
        {
            var text = SafePatternString(value);
            if (!string.IsNullOrWhiteSpace(text))
            {
                return text;
            }
        }

        return string.Empty;
    }

    private static string SafePatternString(object? value)
    {
        if (value is null)
        {
            return string.Empty;
        }

        if (value is string text)
        {
            return text;
        }

        try
        {
            if (value.GetType().GetProperty("Value")?.GetValue(value) is string propertyValue)
            {
                return propertyValue;
            }
        }
        catch (Exception)
        {
        }

        return value.ToString() ?? string.Empty;
    }

    private static IReadOnlyList<AutomationElement> ReadChildren(
        FlaUI.Core.ITreeWalker walker,
        AutomationElement element)
    {
        var children = new List<AutomationElement>();
        var child = walker.GetFirstChild(element);
        while (child is not null)
        {
            children.Add(child);
            child = walker.GetNextSibling(child);
        }

        return children;
    }

    public static UiaNode ReadNode(
        Func<string?> automationId,
        Func<string?> name,
        Func<string?> controlType,
        Func<string?> className,
        Func<string?> helpText)
    {
        ArgumentNullException.ThrowIfNull(automationId);
        ArgumentNullException.ThrowIfNull(name);
        ArgumentNullException.ThrowIfNull(controlType);
        ArgumentNullException.ThrowIfNull(className);
        ArgumentNullException.ThrowIfNull(helpText);

        return new UiaNode(
            AutomationId: SafeRead(automationId),
            Name: SafeRead(name),
            ControlType: SafeRead(controlType),
            ClassName: SafeRead(className),
            HelpText: SafeRead(helpText));
    }

    private static string SafeRead(Func<string?> read)
    {
        try
        {
            return SafeString(read());
        }
        catch (Exception ex) when (IsTransientUiaException(ex))
        {
            return string.Empty;
        }
    }

    private static bool IsTransientUiaException(Exception ex)
    {
        return UiaExceptionClassifier.IsTransient(ex);
    }

    private static string SafeString(string? value)
    {
        return value ?? string.Empty;
    }

    private static void ConfigureAutomationTimeouts(UIA3Automation automation)
    {
        automation.TransactionTimeout = TimeSpan.FromMilliseconds(250);
        automation.ConnectionTimeout = TimeSpan.FromMilliseconds(250);
    }

    private static void AddSnapshotWarning(
        ICollection<string> summary,
        BoundedUiaTreeSnapshot<UiaNode> snapshot)
    {
        var warning = BuildSnapshotWarning(snapshot);
        if (!string.IsNullOrWhiteSpace(warning))
        {
            summary.Add(warning);
        }
    }

    private static string BuildSnapshotWarning(BoundedUiaTreeSnapshot<UiaNode> snapshot)
    {
        if (!snapshot.TruncatedByNodeLimit
            && !snapshot.TruncatedByDepthLimit
            && !snapshot.TruncatedByTimeLimit
            && snapshot.SkippedChildren == 0)
        {
            return string.Empty;
        }

        return "uia-snapshot-warning nodes="
            + snapshot.Nodes.Count
            + " nodeLimit="
            + snapshot.TruncatedByNodeLimit
            + " depthLimit="
            + snapshot.TruncatedByDepthLimit
            + " timeLimit="
            + snapshot.TruncatedByTimeLimit
            + " skippedChildren="
            + snapshot.SkippedChildren
            + " elapsedMs="
            + Math.Round(snapshot.Elapsed.TotalMilliseconds);
    }

    private static string BuildElementSnapshotWarning(BoundedUiaTreeSnapshot<ElementNode> snapshot)
    {
        if (!snapshot.TruncatedByNodeLimit
            && !snapshot.TruncatedByDepthLimit
            && !snapshot.TruncatedByTimeLimit
            && snapshot.SkippedChildren == 0)
        {
            return string.Empty;
        }

        return "uia-root-snapshot-warning nodes="
            + snapshot.Nodes.Count
            + " nodeLimit="
            + snapshot.TruncatedByNodeLimit
            + " depthLimit="
            + snapshot.TruncatedByDepthLimit
            + " timeLimit="
            + snapshot.TruncatedByTimeLimit
            + " skippedChildren="
            + snapshot.SkippedChildren
            + " elapsedMs="
            + Math.Round(snapshot.Elapsed.TotalMilliseconds);
    }

    private sealed record ElementNode(AutomationElement Element, UiaNode Node);

    private sealed record FocusedMessageSurfaceSnapshot(
        IReadOnlyList<UiaNode> Nodes,
        int SurfaceCount,
        IReadOnlyList<string> Warnings);
}
