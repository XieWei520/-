using FlaUI.Core.AutomationElements;
using FlaUI.Core.Definitions;
using FlaUI.Core.Input;
using FlaUI.Core.WindowsAPI;
using FlaUI.UIA3;
using DingTalkWindowsHost.Automation.Capture;
using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Contracts.Services;
using System.Drawing;
using System.Runtime.InteropServices;

namespace DingTalkWindowsHost.Automation.WindowHost;

public sealed class DingTalkMessageNavigator : IDingTalkMessageNavigator
{
    private const int WmClose = 0x0010;
    internal const string MessageNavigatorAutomationId = "navigator_view.im_im";
    internal const string MessageNavigatorAppItemAutomationIdSuffix = "NavigatorAppItemContainer.im_im";
    internal const string MessageNavigatorSearchInputAutomationId = "keep-focus-input";
    private static readonly TimeSpan NavigationUiaTimeout = TimeSpan.FromMilliseconds(500);
    private static readonly TimeSpan ReadinessRetryDelay = TimeSpan.FromMilliseconds(350);

    private readonly DingTalkWindowLocator? _windowLocator;

    public DingTalkMessageNavigator()
        : this(null)
    {
    }

    public DingTalkMessageNavigator(DingTalkWindowLocator? windowLocator)
    {
        _windowLocator = windowLocator;
    }

    public DingTalkNavigationResult OpenMessages(IntPtr windowHandle)
    {
        var attemptedAt = DateTimeOffset.UtcNow;
        var targetWindowHandle = windowHandle;
        if (windowHandle == IntPtr.Zero)
        {
            return BuildResult(
                DingTalkNavigationStatus.NoWindow,
                string.Empty,
                "No DingTalk window handle is available for navigation.",
                attemptedAt);
        }

        try
        {
            using var automation = new UIA3Automation
            {
                TransactionTimeout = NavigationUiaTimeout,
                ConnectionTimeout = NavigationUiaTimeout,
            };
            TryCloseSearchOverlayInContentCandidates(automation, windowHandle);

            targetWindowHandle = ResolveNavigationWindowHandle(automation, targetWindowHandle);
            var root = automation.FromHandle(targetWindowHandle);
            var closedOverlay = TryCloseSearchOverlay(automation, root);
            if (closedOverlay)
            {
                if (IsTransientOverlayWindow(root))
                {
                    _ = PostMessage(targetWindowHandle, WmClose, IntPtr.Zero, IntPtr.Zero);
                }

                Thread.Sleep(300);
                targetWindowHandle = ResolveNavigationWindowHandle(automation, targetWindowHandle);
                root = automation.FromHandle(targetWindowHandle);
            }

            var target = FindNavigatorButton(automation, root);
            var conversationListVisible = IsConversationListVisible(automation, targetWindowHandle);
            if (target is null && !conversationListVisible)
            {
                conversationListVisible = TryWaitForConversationListVisible(automation, targetWindowHandle);
            }

            var navigatorActivated = false;
            var selectedFirstConversation = false;
            var fallbackActivationAttempted = false;
            var recoverableFailure = string.Empty;

            if (target is null && !conversationListVisible)
            {
                fallbackActivationAttempted = true;
                navigatorActivated = TryActivateMessageNavigatorFallback(
                    automation,
                    targetWindowHandle,
                    out var fallbackFailure);
                recoverableFailure = fallbackFailure;
                if (navigatorActivated)
                {
                    Thread.Sleep(500);
                    conversationListVisible = IsConversationListVisible(automation, targetWindowHandle)
                        || TryWaitForConversationListVisible(automation, targetWindowHandle);
                }
            }

            if (target is null && !conversationListVisible && !navigatorActivated)
            {
                return BuildResult(
                    DingTalkNavigationStatus.TargetNotFound,
                    FormatHandle(targetWindowHandle),
                    BuildOpenMessagesMessage(
                        navigatorActivated,
                        selectedFirstConversation,
                        conversationListVisible,
                        recoverableFailure),
                    attemptedAt);
            }

            if (target is not null)
            {
                try
                {
                    ActivateTarget(target);
                    navigatorActivated = true;
                    Thread.Sleep(300);
                    conversationListVisible = IsConversationListVisible(automation, targetWindowHandle);
                }
                catch (Exception ex) when (IsRecoverableNavigationException(ex))
                {
                    recoverableFailure = FormatRecoverableNavigationFailure(ex);
                }
            }

            if (ShouldTryNavigatorFallbackAfterActivation(
                    navigatorActivated,
                    conversationListVisible,
                    fallbackActivationAttempted))
            {
                fallbackActivationAttempted = true;
                var fallbackActivated = TryActivateMessageNavigatorFallback(
                    automation,
                    targetWindowHandle,
                    out var fallbackFailure);
                if (!string.IsNullOrWhiteSpace(fallbackFailure))
                {
                    recoverableFailure = string.IsNullOrWhiteSpace(recoverableFailure)
                        ? fallbackFailure
                        : recoverableFailure + "; " + fallbackFailure;
                }

                navigatorActivated |= fallbackActivated;
                if (fallbackActivated)
                {
                    Thread.Sleep(500);
                    conversationListVisible = IsConversationListVisible(automation, targetWindowHandle)
                        || TryWaitForConversationListVisible(automation, targetWindowHandle);
                }
            }

            try
            {
                selectedFirstConversation = TrySelectFirstConversation(automation, targetWindowHandle);
                conversationListVisible |= selectedFirstConversation
                    || IsConversationListVisible(automation, targetWindowHandle);
            }
            catch (Exception ex) when (IsRecoverableNavigationException(ex))
            {
                recoverableFailure = string.IsNullOrWhiteSpace(recoverableFailure)
                    ? FormatRecoverableNavigationFailure(ex)
                    : recoverableFailure + "; " + FormatRecoverableNavigationFailure(ex);
                conversationListVisible = IsConversationListVisible(automation, targetWindowHandle);
            }

            if (!selectedFirstConversation)
            {
                selectedFirstConversation = TryWaitForSelectionConfirmed(automation, targetWindowHandle);
                conversationListVisible |= selectedFirstConversation;
            }

            if (!conversationListVisible)
            {
                conversationListVisible = TryWaitForConversationListVisible(automation, targetWindowHandle);
            }

            return BuildResult(
                ResolveOpenMessagesStatus(navigatorActivated, conversationListVisible),
                FormatHandle(targetWindowHandle),
                BuildOpenMessagesMessage(
                    navigatorActivated,
                    selectedFirstConversation,
                    conversationListVisible,
                    recoverableFailure),
                attemptedAt);
        }
        catch (Exception ex) when (IsRecoverableNavigationException(ex))
        {
            return BuildResult(
                ResolveRecoverableOpenMessagesStatus(
                    navigatorActivated: false,
                    conversationListVisible: false),
                FormatHandle(targetWindowHandle),
                "DingTalk messages navigation failed: " + FormatRecoverableNavigationFailure(ex),
                attemptedAt);
        }
    }

    public DingTalkNavigationResult CloseSearchOverlay(IntPtr windowHandle)
    {
        var attemptedAt = DateTimeOffset.UtcNow;
        try
        {
            using var automation = new UIA3Automation
            {
                TransactionTimeout = NavigationUiaTimeout,
                ConnectionTimeout = NavigationUiaTimeout,
            };

            var closeAttempted = TryCloseSearchOverlayInContentCandidates(automation, windowHandle);
            if (!closeAttempted && windowHandle != IntPtr.Zero)
            {
                var root = automation.FromHandle(windowHandle);
                closeAttempted = TryCloseSearchOverlay(automation, root);
                if (closeAttempted && IsTransientOverlayWindow(root))
                {
                    _ = PostMessage(windowHandle, WmClose, IntPtr.Zero, IntPtr.Zero);
                }
            }

            var stillPresent = windowHandle != IntPtr.Zero
                ? IsSearchOverlayPresent(automation, windowHandle)
                : IsSearchOverlayPresentInContentCandidates(automation, windowHandle);
            var status = windowHandle == IntPtr.Zero && !closeAttempted
                ? DingTalkNavigationStatus.NoWindow
                : ResolveCloseSearchOverlayStatus(closeAttempted, stillPresent);

            return new DingTalkNavigationResult(
                Status: status,
                TargetHwnd: FormatHandle(windowHandle),
                TargetAutomationId: "advancedSearch",
                Message: windowHandle == IntPtr.Zero && !closeAttempted
                    ? "No DingTalk window handle is available and no overlay candidate was detected."
                    : !closeAttempted
                    ? "DingTalk search overlay was not detected."
                    : stillPresent
                        ? "DingTalk search overlay close was attempted, but the overlay is still present."
                        : "DingTalk search overlay was closed.",
                AttemptedAt: attemptedAt);
        }
        catch (Exception ex)
        {
            return new DingTalkNavigationResult(
                Status: DingTalkNavigationStatus.Failed,
                TargetHwnd: FormatHandle(windowHandle),
                TargetAutomationId: "advancedSearch",
                Message: "DingTalk search overlay close failed: " + FormatRecoverableNavigationFailure(ex),
                AttemptedAt: attemptedAt);
        }
    }

    internal IntPtr ResolveNavigationWindowHandle(IntPtr currentWindowHandle)
    {
        if (_windowLocator is null)
        {
            return currentWindowHandle;
        }

        var candidates = _windowLocator.GetWindowCandidates();
        var currentCandidate = candidates.FirstOrDefault(candidate => candidate.Handle == currentWindowHandle);
        if (currentCandidate is not null && ShouldRetainCurrentNavigationWindow(currentCandidate))
        {
            return currentWindowHandle;
        }

        var selected = _windowLocator.ChooseMainWindow(candidates);
        return selected is null ? currentWindowHandle : selected.Handle;
    }

    private IntPtr ResolveNavigationWindowHandle(UIA3Automation automation, IntPtr currentWindowHandle)
    {
        if (currentWindowHandle != IntPtr.Zero && IsConversationListVisible(automation, currentWindowHandle))
        {
            return currentWindowHandle;
        }

        if (currentWindowHandle != IntPtr.Zero && IsNavigationShellVisible(automation, currentWindowHandle))
        {
            return currentWindowHandle;
        }

        return ResolveNavigationWindowHandle(currentWindowHandle);
    }

    private static AutomationElement? FindNavigatorButton(
        UIA3Automation automation,
        AutomationElement root)
    {
        var walker = automation.TreeWalkerFactory.GetControlViewWalker();
        var snapshot = BoundedUiaTreeWalker.Walk(
            root,
            maxNodes: 512,
            maxDepth: 8,
            timeBudget: TimeSpan.FromMilliseconds(800),
            static element => new ElementNode(element, ReadElementNodeOrEmpty(element)),
            element => ReadChildren(walker, element));

        return snapshot.Nodes
            .Where(static pair => IsMessageNavigatorNode(pair.Node))
            .OrderByDescending(static pair => GetMessageNavigatorNodePriority(pair.Node))
            .ThenBy(static pair => pair.Element.BoundingRectangle.Top)
            .FirstOrDefault()
            ?.Element;
    }

    private static bool IsConversationListVisible(
        UIA3Automation automation,
        IntPtr windowHandle)
    {
        try
        {
            var root = automation.FromHandle(windowHandle);
            return ReadConversationDiagnostics(automation, root).Conversations.Count > 0;
        }
        catch (Exception ex) when (IsRecoverableNavigationException(ex))
        {
            return false;
        }
    }

    private static bool TrySelectFirstConversation(
        UIA3Automation automation,
        IntPtr windowHandle)
    {
        var root = automation.FromHandle(windowHandle);
        var diagnostics = ReadConversationDiagnostics(automation, root);
        if (IsConversationSelectionConfirmed(diagnostics))
        {
            return true;
        }

        if (!ShouldSelectFirstConversation(diagnostics))
        {
            return false;
        }

        var targets = FindFirstConversationListTargets(automation, root);
        if (targets.FirstItem is null && targets.Container is null)
        {
            return false;
        }

        return SelectConversation(automation, windowHandle, targets.FirstItem, targets.Container);
    }

    private static UiaConversationDiagnosticsResult ReadConversationDiagnostics(
        UIA3Automation automation,
        AutomationElement root)
    {
        var walker = automation.TreeWalkerFactory.GetControlViewWalker();
        var snapshot = BoundedUiaTreeWalker.Walk(
            root,
            maxNodes: 512,
            maxDepth: 8,
            timeBudget: TimeSpan.FromMilliseconds(800),
            ReadElementNode,
            element => ReadChildren(walker, element));

        return UiaConversationDiagnosticsExtractor.Extract(snapshot.Nodes, limit: 50);
    }

    private static ConversationListTargets FindFirstConversationListTargets(
        UIA3Automation automation,
        AutomationElement root)
    {
        var walker = automation.TreeWalkerFactory.GetControlViewWalker();
        var snapshot = BoundedUiaTreeWalker.Walk(
            root,
            maxNodes: 512,
            maxDepth: 8,
            timeBudget: TimeSpan.FromMilliseconds(800),
            element => new ElementNode(element, ReadElementNode(element)),
            element => ReadChildren(walker, element));

        foreach (var container in snapshot.Nodes.Where(static pair => IsConversationListContainerNode(pair.Node)))
        {
            var item = container.Element.FindAllDescendants(cf => cf.ByControlType(ControlType.ListItem))
                .FirstOrDefault();
            return new ConversationListTargets(container.Element, item);
        }

        return new ConversationListTargets(null, null);
    }

    private static bool TryCloseSearchOverlay(UIA3Automation automation, AutomationElement root)
    {
        if (!ContainsSearchOverlay(automation, root))
        {
            return false;
        }

        if (TryCloseSearchOverlayWithDismissControl(root))
        {
            return true;
        }

        TryNavigateBackFromSearchOverlay(root);
        return true;
    }

    private static bool TryCloseSearchOverlayWithDismissControl(AutomationElement root)
    {
        var dismissTarget = FindSearchOverlayDismissControl(root);
        if (dismissTarget is null)
        {
            return false;
        }

        ActivateDismissTarget(dismissTarget);
        return true;
    }

    private static bool TryNavigateBackFromSearchOverlay(AutomationElement root)
    {
        var searchInput = root.FindFirstDescendant(MessageNavigatorSearchInputAutomationId);
        if (searchInput is not null)
        {
            searchInput.Focus();
        }
        else
        {
            root.Focus();
        }

        Keyboard.TypeSimultaneously(VirtualKeyShort.ALT, VirtualKeyShort.LEFT);
        Keyboard.Press(VirtualKeyShort.ESCAPE);
        return true;
    }

    private static AutomationElement? FindSearchOverlayDismissControl(AutomationElement root)
    {
        var candidates = root.FindAllDescendants(cf => cf.ByControlType(ControlType.Button))
            .Concat(root.FindAllDescendants(cf => cf.ByControlType(ControlType.Image)))
            .Concat(root.FindAllDescendants(cf => cf.ByControlType(ControlType.TabItem)));

        foreach (var candidate in candidates)
        {
            if (IsSearchOverlayDismissNode(UiaChatSurfaceProbe.ReadNode(
                    () => candidate.AutomationId,
                    () => candidate.Name,
                    () => candidate.ControlType.ToString(),
                    () => candidate.ClassName,
                    () => candidate.HelpText)))
            {
                return candidate;
            }
        }

        return null;
    }

    private bool TryCloseSearchOverlayInContentCandidates(
        UIA3Automation automation,
        IntPtr hostWindowHandle)
    {
        if (_windowLocator is null)
        {
            return false;
        }

        var closeAttempted = false;
        foreach (var candidate in _windowLocator.GetWindowCandidates()
                     .Where(candidate => candidate.Handle != hostWindowHandle)
                     .Where(IsSearchOverlayProbeCandidate)
                     .OrderByDescending(static candidate => candidate.Area)
                     .ThenBy(static candidate => candidate.ZOrder)
                     .Take(12))
        {
            AutomationElement candidateRoot;
            try
            {
                candidateRoot = automation.FromHandle(candidate.Handle);
            }
            catch (Exception ex) when (UiaExceptionClassifier.IsTransient(ex) || ex is InvalidOperationException)
            {
                continue;
            }

            try
            {
                if (!TryCloseSearchOverlay(automation, candidateRoot))
                {
                    continue;
                }

                closeAttempted = true;
                if (IsTransientOverlayWindow(candidateRoot))
                {
                    _ = PostMessage(candidate.Handle, WmClose, IntPtr.Zero, IntPtr.Zero);
                }
            }
            catch (Exception ex) when (IsRecoverableNavigationException(ex))
            {
                continue;
            }

            Thread.Sleep(300);
        }

        return closeAttempted;
    }

    private bool IsSearchOverlayPresent(UIA3Automation automation, IntPtr hostWindowHandle)
    {
        try
        {
            var root = automation.FromHandle(hostWindowHandle);
            if (ContainsSearchOverlay(automation, root))
            {
                return true;
            }
        }
        catch (Exception ex) when (UiaExceptionClassifier.IsTransient(ex) || ex is InvalidOperationException)
        {
        }

        return IsSearchOverlayPresentInContentCandidates(automation, hostWindowHandle);
    }

    private bool IsSearchOverlayPresentInContentCandidates(
        UIA3Automation automation,
        IntPtr hostWindowHandle)
    {
        if (_windowLocator is null)
        {
            return false;
        }

        foreach (var candidate in _windowLocator.GetWindowCandidates()
                     .Where(candidate => candidate.Handle != hostWindowHandle)
                     .Where(IsSearchOverlayProbeCandidate)
                     .OrderByDescending(static candidate => candidate.Area)
                     .ThenBy(static candidate => candidate.ZOrder)
                     .Take(12))
        {
            try
            {
                var root = automation.FromHandle(candidate.Handle);
                if (ContainsSearchOverlay(automation, root))
                {
                    return true;
                }
            }
            catch (Exception ex) when (UiaExceptionClassifier.IsTransient(ex) || ex is InvalidOperationException)
            {
                continue;
            }
        }

        return false;
    }

    private static bool ContainsSearchOverlay(UIA3Automation automation, AutomationElement root)
    {
        var walker = automation.TreeWalkerFactory.GetControlViewWalker();
        var snapshot = BoundedUiaTreeWalker.Walk(
            root,
            maxNodes: 160,
            maxDepth: 6,
            timeBudget: TimeSpan.FromMilliseconds(500),
            ReadSearchOverlaySignal,
            element => ReadChildren(walker, element));

        return snapshot.Nodes.Any(static signal => signal);
    }

    private static bool IsTransientOverlayWindow(AutomationElement root)
    {
        try
        {
            return IsSearchOverlayNode(ReadElementNode(root));
        }
        catch (Exception ex) when (UiaExceptionClassifier.IsTransient(ex))
        {
            return false;
        }
    }

    internal static bool IsSearchOverlayProbeCandidate(WindowCandidate candidate)
    {
        if (candidate.Handle == IntPtr.Zero
            || !candidate.IsEnabled
            || !candidate.IsVisible
            || candidate.IsToolWindow
            || candidate.Width < 320
            || candidate.Height < 240
            || !string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        return string.Equals(candidate.ClassName, "Chrome_RenderWidgetHostHWND", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "Chrome_WidgetWin_1", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "CefBrowserWindow", StringComparison.OrdinalIgnoreCase)
            || (candidate.IsTopLevel
                && string.Equals(candidate.ClassName, "Qt51511QWindowIcon", StringComparison.OrdinalIgnoreCase))
            || IsTransientOverlayClass(candidate.ClassName);
    }

    private static bool ReadSearchOverlaySignal(AutomationElement element)
    {
        try
        {
            return IsSearchOverlayNode(ReadElementNode(element));
        }
        catch (Exception ex) when (UiaExceptionClassifier.IsTransient(ex))
        {
            return false;
        }
    }

    internal static bool IsSearchOverlayNode(UiaNode node)
    {
        return node.AutomationId.Contains("advancedSearch", StringComparison.OrdinalIgnoreCase)
            || node.AutomationId.Contains("keep-focus-input", StringComparison.OrdinalIgnoreCase)
            || node.AutomationId.Contains("DTIMChatAt", StringComparison.OrdinalIgnoreCase)
            || node.AutomationId.Contains("AiAssistTrayMenuPanel", StringComparison.OrdinalIgnoreCase)
            || string.Equals(node.Name, "\u641c\u7d22\u6216\u63d0\u95ee", StringComparison.OrdinalIgnoreCase)
            || DingTalkTransientOverlayClassifier.IsTransientOverlay(node.ClassName, node.Name);
    }

    internal static bool IsSearchOverlayDismissNode(UiaNode node)
    {
        return IsDismissSignal(node.AutomationId)
            || IsDismissSignal(node.Name)
            || IsDismissSignal(node.HelpText);
    }

    internal static DingTalkNavigationStatus ResolveCloseSearchOverlayStatus(
        bool closeAttempted,
        bool stillPresent)
    {
        return !closeAttempted
            ? DingTalkNavigationStatus.NotPresent
            : stillPresent
                ? DingTalkNavigationStatus.Failed
                : DingTalkNavigationStatus.Closed;
    }

    private static bool IsDismissSignal(string value)
    {
        return value.Contains("close", StringComparison.OrdinalIgnoreCase)
            || value.Contains("back", StringComparison.OrdinalIgnoreCase)
            || value.Contains("\u8fd4\u56de", StringComparison.OrdinalIgnoreCase)
            || value.Contains("\u5173\u95ed", StringComparison.OrdinalIgnoreCase)
            || value.Contains("\u53d6\u6d88", StringComparison.OrdinalIgnoreCase)
            || value.Contains("\u9000\u51fa", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsTransientOverlayClass(string className)
    {
        return DingTalkTransientOverlayClassifier.IsTransientOverlay(className, string.Empty);
    }

    private static bool IsRecoverableNavigationException(Exception ex)
    {
        return UiaExceptionClassifier.IsTransient(ex)
            || ex is NotSupportedException
            || ex is ArgumentException
            || ex is FlaUI.Core.Exceptions.NoClickablePointException
            || ex is ExternalException;
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

    internal static bool IsMessageNavigatorNode(UiaNode node)
    {
        return IsMessageNavigatorAutomationId(node.AutomationId)
            || (string.Equals(node.Name, "\u6d88\u606f", StringComparison.OrdinalIgnoreCase)
                && string.Equals(node.ControlType, "Button", StringComparison.OrdinalIgnoreCase));
    }

    private static bool IsMessageNavigatorAutomationId(string automationId)
    {
        return string.Equals(automationId, MessageNavigatorAutomationId, StringComparison.OrdinalIgnoreCase)
            || automationId.EndsWith(
                MessageNavigatorAppItemAutomationIdSuffix,
                StringComparison.OrdinalIgnoreCase);
    }

    private static int GetMessageNavigatorNodePriority(UiaNode node)
    {
        return IsMessageNavigatorAutomationId(node.AutomationId)
            ? 2
            : 1;
    }

    internal static bool ShouldSelectFirstConversation(UiaConversationDiagnosticsResult diagnostics)
    {
        ArgumentNullException.ThrowIfNull(diagnostics);

        return ConversationReadinessEvaluator.Evaluate(diagnostics) == ConversationReadiness.ConversationListVisible;
    }

    internal static DingTalkNavigationStatus ResolveOpenMessagesStatus(
        bool navigatorActivated,
        bool conversationListVisible)
    {
        _ = navigatorActivated;
        return conversationListVisible
            ? DingTalkNavigationStatus.Activated
            : DingTalkNavigationStatus.TargetNotFound;
    }

    internal static DingTalkNavigationStatus ResolveRecoverableOpenMessagesStatus(
        bool navigatorActivated,
        bool conversationListVisible)
    {
        return ResolveOpenMessagesStatus(navigatorActivated, conversationListVisible);
    }

    internal static bool ShouldTryNavigatorFallbackAfterActivation(
        bool navigatorActivated,
        bool conversationListVisible,
        bool fallbackAlreadyAttempted)
    {
        return navigatorActivated
            && !conversationListVisible
            && !fallbackAlreadyAttempted;
    }

    internal static string BuildOpenMessagesMessage(
        bool navigatorActivated,
        bool selectedFirstConversation,
        bool conversationListVisible,
        string recoverableFailure)
    {
        var suffix = string.IsNullOrWhiteSpace(recoverableFailure)
            ? string.Empty
            : " Degraded after recoverable UIA failure: " + recoverableFailure;

        if (selectedFirstConversation)
        {
            return navigatorActivated
                ? "DingTalk messages navigator button was activated and the active conversation surface was confirmed."
                    + suffix
                : "DingTalk messages view was already visible and the active conversation surface was confirmed."
                    + suffix;
        }

        if (navigatorActivated)
        {
            return conversationListVisible
                ? "DingTalk messages navigator button was activated, but first conversation selection was not confirmed."
                    + suffix
                : "DingTalk messages navigator button was activated, but the conversation list was not confirmed."
                    + suffix;
        }

        if (conversationListVisible)
        {
            return "DingTalk messages view was already visible; reporting degraded navigation success." + suffix;
        }

        return "DingTalk messages navigator button was not exposed through UIA." + suffix;
    }

    internal static string FormatRecoverableNavigationFailure(Exception exception)
    {
        ArgumentNullException.ThrowIfNull(exception);

        var message = exception.Message;
        return string.IsNullOrWhiteSpace(message)
            ? exception.GetType().Name + " HResult=0x" + exception.HResult.ToString("X8")
            : exception.GetType().Name
                + " HResult=0x"
                + exception.HResult.ToString("X8")
                + " Message="
                + message;
    }

    internal static bool IsConversationListContainerNode(UiaNode node)
    {
        return node.AutomationId.Contains("ConvListView", StringComparison.OrdinalIgnoreCase)
            || string.Equals(node.ClassName, "ConvListItemListView", StringComparison.OrdinalIgnoreCase);
    }

    internal static bool ShouldRetainCurrentNavigationWindow(WindowCandidate candidate)
    {
        if (candidate.Handle == IntPtr.Zero
            || !string.Equals(candidate.ProcessName, "DingTalk", StringComparison.OrdinalIgnoreCase)
            || !candidate.IsEnabled
            || candidate.IsToolWindow
            || DingTalkTransientOverlayClassifier.IsTransientOverlay(candidate))
        {
            return false;
        }

        return string.Equals(candidate.ClassName, "StandardFrame_DingTalk", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "DingChatWnd", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "CefBrowserWindow", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "Chrome_WidgetWin_0", StringComparison.OrdinalIgnoreCase)
            || string.Equals(candidate.ClassName, "Chrome_WidgetWin_1", StringComparison.OrdinalIgnoreCase)
            || (string.Equals(candidate.ClassName, "Qt51511QWindowIcon", StringComparison.OrdinalIgnoreCase)
                && (string.Equals(candidate.Title, "\u9489\u9489", StringComparison.OrdinalIgnoreCase)
                    || string.Equals(candidate.Title, "DingTalk", StringComparison.OrdinalIgnoreCase)
                    || string.Equals(candidate.Title, "DTIMChatModule", StringComparison.OrdinalIgnoreCase)));
    }

    internal static bool IsConversationSelectionConfirmed(UiaConversationDiagnosticsResult diagnostics)
    {
        ArgumentNullException.ThrowIfNull(diagnostics);

        return ConversationReadinessEvaluator.Evaluate(diagnostics) == ConversationReadiness.Ready;
    }

    private static UiaNode ReadElementNode(AutomationElement element)
    {
        return UiaChatSurfaceProbe.ReadNode(
            () => element.AutomationId,
            () => element.Name,
            () => element.ControlType.ToString(),
            () => element.ClassName,
            () => element.HelpText);
    }

    private static UiaNode ReadElementNodeOrEmpty(AutomationElement element)
    {
        try
        {
            return ReadElementNode(element);
        }
        catch (Exception ex) when (UiaExceptionClassifier.IsTransient(ex))
        {
            return new UiaNode(
                AutomationId: string.Empty,
                Name: string.Empty,
                ControlType: string.Empty);
        }
    }

    private static bool IsNavigationShellVisible(UIA3Automation automation, IntPtr windowHandle)
    {
        try
        {
            var root = automation.FromHandle(windowHandle);
            if (IsNavigationShellNode(ReadElementNode(root)))
            {
                return true;
            }

            var walker = automation.TreeWalkerFactory.GetControlViewWalker();
            var snapshot = BoundedUiaTreeWalker.Walk(
                root,
                maxNodes: 160,
                maxDepth: 5,
                timeBudget: TimeSpan.FromMilliseconds(500),
                ReadNavigationShellSignal,
                element => ReadChildren(walker, element));

            return snapshot.Nodes.Any(static value => value);
        }
        catch (Exception ex) when (IsRecoverableNavigationException(ex))
        {
            return false;
        }
    }

    private static bool ReadNavigationShellSignal(AutomationElement element)
    {
        try
        {
            return IsNavigationShellNode(ReadElementNode(element));
        }
        catch (Exception ex) when (UiaExceptionClassifier.IsTransient(ex))
        {
            return false;
        }
    }

    private static bool IsNavigationShellNode(UiaNode node)
    {
        return node.AutomationId.Contains("dt_main_frame_view", StringComparison.OrdinalIgnoreCase)
            || node.AutomationId.Contains("navigator_view", StringComparison.OrdinalIgnoreCase)
            || node.AutomationId.Contains("DtContentAreaViewClass", StringComparison.OrdinalIgnoreCase)
            || node.ClassName.Contains("DtMainFrameView", StringComparison.OrdinalIgnoreCase)
            || node.ClassName.Contains("NavigatorView", StringComparison.OrdinalIgnoreCase)
            || node.ClassName.Contains("DtContentAreaView", StringComparison.OrdinalIgnoreCase);
    }

    private static bool SelectConversation(
        UIA3Automation automation,
        IntPtr windowHandle,
        AutomationElement? target,
        AutomationElement? container)
    {
        TryBringWindowToForeground(windowHandle);

        if (target is not null && target.Patterns.SelectionItem.TryGetPattern(out var selectionPattern))
        {
            try
            {
                selectionPattern.Select();
                Thread.Sleep(250);
                if (IsSelectionConfirmed(automation, windowHandle))
                {
                    return true;
                }
            }
            catch (Exception ex) when (IsRecoverableNavigationException(ex))
            {
            }
        }

        if (target is not null && TryClickConversationRow(automation, windowHandle, target))
        {
            return true;
        }

        if (container is not null && TryClickConversationListContainer(automation, windowHandle, container))
        {
            return true;
        }

        if (target is not null)
        {
            try
            {
                ActivateTarget(target);
            }
            catch (Exception ex) when (IsRecoverableNavigationException(ex))
            {
            }

            Thread.Sleep(250);
        }

        return IsSelectionConfirmed(automation, windowHandle);
    }

    internal static bool TryBuildConversationClickPoint(Rectangle boundingRectangle, out Point clickPoint)
    {
        clickPoint = default;
        return TryBuildConversationClickPoints(boundingRectangle, out var clickPoints)
            && TryGetFirstPoint(clickPoints, out clickPoint);
    }

    internal static bool TryBuildConversationClickPoints(
        Rectangle boundingRectangle,
        out IReadOnlyList<Point> clickPoints)
    {
        clickPoints = Array.Empty<Point>();

        if (boundingRectangle.Width <= 0 || boundingRectangle.Height <= 0)
        {
            return false;
        }

        var maxOffset = Math.Max(1, boundingRectangle.Width - 8);
        var contentOffset = Math.Min(Math.Max(88, boundingRectangle.Width * 2 / 5), maxOffset);
        var fallbackOffset = Math.Min(Math.Max(48, boundingRectangle.Width / 4), maxOffset);
        var centerOffset = Math.Min(Math.Max(1, boundingRectangle.Width / 2), maxOffset);
        var yOffset = Math.Max(1, boundingRectangle.Height / 2);
        clickPoints = new[]
        {
            new Point(boundingRectangle.Left + contentOffset, boundingRectangle.Top + yOffset),
            new Point(boundingRectangle.Left + fallbackOffset, boundingRectangle.Top + yOffset),
            new Point(boundingRectangle.Left + centerOffset, boundingRectangle.Top + yOffset),
        }.Distinct().ToArray();
        return true;
    }

    internal static bool TryBuildConversationListClickPoints(
        Rectangle boundingRectangle,
        out IReadOnlyList<Point> clickPoints)
    {
        clickPoints = Array.Empty<Point>();

        if (boundingRectangle.Width <= 0 || boundingRectangle.Height <= 0)
        {
            return false;
        }

        var maxOffset = Math.Max(1, boundingRectangle.Width - 8);
        var contentOffset = Math.Min(Math.Max(88, boundingRectangle.Width * 2 / 5), maxOffset);
        var fallbackOffset = Math.Min(Math.Max(48, boundingRectangle.Width / 4), maxOffset);
        var centerOffset = Math.Min(Math.Max(1, boundingRectangle.Width / 2), maxOffset);
        var yOffset = Math.Min(36, Math.Max(1, boundingRectangle.Height / 2));
        clickPoints = new[]
        {
            new Point(boundingRectangle.Left + contentOffset, boundingRectangle.Top + yOffset),
            new Point(boundingRectangle.Left + fallbackOffset, boundingRectangle.Top + yOffset),
            new Point(boundingRectangle.Left + centerOffset, boundingRectangle.Top + yOffset),
        }.Distinct().ToArray();
        return true;
    }

    private static bool TryGetFirstPoint(IReadOnlyList<Point> points, out Point point)
    {
        if (points.Count == 0)
        {
            point = default;
            return false;
        }

        point = points[0];
        return true;
    }

    private static bool TryClickConversationRow(
        UIA3Automation automation,
        IntPtr windowHandle,
        AutomationElement target)
    {
        try
        {
            if (!TryBuildConversationClickPoints(target.BoundingRectangle, out var clickPoints))
            {
                return false;
            }

            target.Focus();
            foreach (var clickPoint in clickPoints)
            {
                TryBringWindowToForeground(windowHandle);
                Mouse.LeftClick(clickPoint);
                Thread.Sleep(350);
                if (IsSelectionConfirmed(automation, windowHandle))
                {
                    return true;
                }
            }

            return false;
        }
        catch (Exception ex) when (IsRecoverableNavigationException(ex))
        {
            return false;
        }
    }

    private static bool TryClickConversationListContainer(
        UIA3Automation automation,
        IntPtr windowHandle,
        AutomationElement container)
    {
        try
        {
            if (!TryBuildConversationListClickPoints(container.BoundingRectangle, out var clickPoints))
            {
                return false;
            }

            TryFocus(container);
            foreach (var clickPoint in clickPoints)
            {
                TryBringWindowToForeground(windowHandle);
                Mouse.LeftClick(clickPoint);
                Thread.Sleep(350);
                if (IsSelectionConfirmed(automation, windowHandle))
                {
                    return true;
                }
            }

            return false;
        }
        catch (Exception ex) when (IsRecoverableNavigationException(ex))
        {
            return false;
        }
    }

    private static bool TryActivateMessageNavigatorFallback(
        UIA3Automation automation,
        IntPtr windowHandle,
        out string failure)
    {
        failure = string.Empty;
        try
        {
            var root = automation.FromHandle(windowHandle);
            var target = FindNavigatorButton(automation, root);
            if (target is not null)
            {
                return TryActivateMessageNavigatorElement(
                    automation,
                    windowHandle,
                    target,
                    out failure);
            }

            var navigator = FindNavigationBar(automation, root);
            if (navigator is null)
            {
                failure = "NavigatorView not exposed through UIA.";
                return false;
            }

            if (!TryBuildMessageNavigatorFallbackClickPoints(
                    navigator.BoundingRectangle,
                    out var clickPoints))
            {
                failure = "NavigatorView has empty bounds.";
                return false;
            }

            TryBringWindowToForeground(windowHandle);
            TryFocus(navigator);
            foreach (var clickPoint in clickPoints)
            {
                Mouse.LeftClick(clickPoint);
                Thread.Sleep(350);
                if (IsConversationListVisible(automation, windowHandle))
                {
                    return true;
                }
            }

            return true;
        }
        catch (Exception ex) when (IsRecoverableNavigationException(ex))
        {
            failure = FormatRecoverableNavigationFailure(ex);
            return false;
        }
    }

    private static bool TryActivateMessageNavigatorElement(
        UIA3Automation automation,
        IntPtr windowHandle,
        AutomationElement target,
        out string failure)
    {
        failure = string.Empty;
        var attempted = false;

        TryBringWindowToForeground(windowHandle);
        TryFocus(target);
        try
        {
            ActivateTarget(target);
            attempted = true;
            Thread.Sleep(350);
            if (IsConversationListVisible(automation, windowHandle))
            {
                return true;
            }
        }
        catch (Exception ex) when (IsRecoverableNavigationException(ex))
        {
            failure = FormatRecoverableNavigationFailure(ex);
        }

        if (!TryBuildMessageNavigatorElementClickPoints(target.BoundingRectangle, out var clickPoints))
        {
            failure = string.IsNullOrWhiteSpace(failure)
                ? "Message navigator element has empty bounds."
                : failure + "; Message navigator element has empty bounds.";
            return attempted;
        }

        foreach (var clickPoint in clickPoints)
        {
            TryBringWindowToForeground(windowHandle);
            Mouse.LeftClick(clickPoint);
            attempted = true;
            Thread.Sleep(350);
            if (IsConversationListVisible(automation, windowHandle))
            {
                return true;
            }
        }

        return attempted;
    }

    private static AutomationElement? FindNavigationBar(
        UIA3Automation automation,
        AutomationElement root)
    {
        var walker = automation.TreeWalkerFactory.GetControlViewWalker();
        var snapshot = BoundedUiaTreeWalker.Walk(
            root,
            maxNodes: 256,
            maxDepth: 6,
            timeBudget: TimeSpan.FromMilliseconds(600),
            element => new ElementNode(element, ReadElementNode(element)),
            element => ReadChildren(walker, element));

        return snapshot.Nodes
            .Where(static pair => IsNavigationBarNode(pair.Node))
            .OrderByDescending(static pair => pair.Element.BoundingRectangle.Height)
            .FirstOrDefault()
            ?.Element;
    }

    private static bool IsNavigationBarNode(UiaNode node)
    {
        return node.AutomationId.Contains("navigator_view", StringComparison.OrdinalIgnoreCase)
            || node.ClassName.Contains("NavigatorView", StringComparison.OrdinalIgnoreCase);
    }

    internal static bool TryBuildMessageNavigatorFallbackClickPoints(
        Rectangle boundingRectangle,
        out IReadOnlyList<Point> clickPoints)
    {
        clickPoints = Array.Empty<Point>();

        if (boundingRectangle.Width <= 0 || boundingRectangle.Height <= 0)
        {
            return false;
        }

        var x = boundingRectangle.Left + Math.Max(1, boundingRectangle.Width / 2);
        var primaryY = boundingRectangle.Top + Math.Min(
            Math.Max(70, boundingRectangle.Height / 8),
            Math.Max(1, boundingRectangle.Height - 8));
        var beforeY = Math.Max(boundingRectangle.Top + 1, primaryY - 16);
        var afterY = Math.Min(boundingRectangle.Bottom - 1, primaryY + 16);
        clickPoints = new[]
        {
            new Point(x, primaryY),
            new Point(x, beforeY),
            new Point(x, afterY),
        }.Distinct().ToArray();
        return true;
    }

    internal static bool TryBuildMessageNavigatorElementClickPoints(
        Rectangle boundingRectangle,
        out IReadOnlyList<Point> clickPoints)
    {
        clickPoints = Array.Empty<Point>();

        if (boundingRectangle.Width <= 0 || boundingRectangle.Height <= 0)
        {
            return false;
        }

        var x = boundingRectangle.Left + Math.Max(1, boundingRectangle.Width / 2);
        var centerY = boundingRectangle.Top + Math.Max(1, boundingRectangle.Height / 2);
        var ySpread = Math.Max(1, boundingRectangle.Height / 4);
        var beforeY = Math.Max(boundingRectangle.Top + 1, centerY - ySpread);
        var afterY = Math.Min(boundingRectangle.Bottom - 1, centerY + ySpread);
        clickPoints = new[]
        {
            new Point(x, centerY),
            new Point(x, beforeY),
            new Point(x, afterY),
        }.Distinct().ToArray();
        return true;
    }

    private static void TryFocus(AutomationElement element)
    {
        try
        {
            element.Focus();
        }
        catch (Exception ex) when (IsRecoverableNavigationException(ex))
        {
        }
    }

    private static bool IsSelectionConfirmed(UIA3Automation automation, IntPtr windowHandle)
    {
        try
        {
            var root = automation.FromHandle(windowHandle);
            return IsConversationSelectionConfirmed(ReadConversationDiagnostics(automation, root));
        }
        catch (Exception ex) when (IsRecoverableNavigationException(ex))
        {
            return false;
        }
    }

    private static bool TryWaitForSelectionConfirmed(
        UIA3Automation automation,
        IntPtr windowHandle,
        int attempts = 4)
    {
        for (var attempt = 0; attempt < attempts; attempt++)
        {
            if (IsSelectionConfirmed(automation, windowHandle))
            {
                return true;
            }

            Thread.Sleep(ReadinessRetryDelay);
        }

        return false;
    }

    private static bool TryWaitForConversationListVisible(
        UIA3Automation automation,
        IntPtr windowHandle,
        int attempts = 4)
    {
        for (var attempt = 0; attempt < attempts; attempt++)
        {
            if (IsConversationListVisible(automation, windowHandle))
            {
                return true;
            }

            Thread.Sleep(ReadinessRetryDelay);
        }

        return false;
    }

    private static void ActivateTarget(AutomationElement target)
    {
        if (target.Patterns.Invoke.TryGetPattern(out var invokePattern))
        {
            invokePattern.Invoke();
            return;
        }

        target.Click(moveMouse: true);
    }

    private static void ActivateDismissTarget(AutomationElement target)
    {
        try
        {
            ActivateTarget(target);
        }
        catch (Exception ex) when (IsRecoverableNavigationException(ex))
        {
        }

        try
        {
            target.Click(moveMouse: true);
        }
        catch (Exception ex) when (IsRecoverableNavigationException(ex))
        {
        }
    }

    private static DingTalkNavigationResult BuildResult(
        DingTalkNavigationStatus status,
        string targetHwnd,
        string message,
        DateTimeOffset attemptedAt)
    {
        return new DingTalkNavigationResult(
            Status: status,
            TargetHwnd: targetHwnd,
            TargetAutomationId: MessageNavigatorAutomationId,
            Message: message,
            AttemptedAt: attemptedAt);
    }

    private static string FormatHandle(IntPtr handle)
    {
        return "0x" + handle.ToInt64().ToString("X");
    }

    private sealed record ElementNode(AutomationElement Element, UiaNode Node);

    private sealed record ConversationListTargets(
        AutomationElement? Container,
        AutomationElement? FirstItem);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool PostMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);

    private static void TryBringWindowToForeground(IntPtr windowHandle)
    {
        if (windowHandle == IntPtr.Zero)
        {
            return;
        }

        _ = SetForegroundWindow(windowHandle);
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetForegroundWindow(IntPtr hWnd);
}
