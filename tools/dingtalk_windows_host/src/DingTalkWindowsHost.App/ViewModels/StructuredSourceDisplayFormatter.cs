using System.Text;
using DingTalkWindowsHost.Contracts.Models;

namespace DingTalkWindowsHost.App.ViewModels;

public static class StructuredSourceDisplayFormatter
{
    public static string FormatSummary(StructuredSourceProbeResult result)
    {
        ArgumentNullException.ThrowIfNull(result);

        var builder = new StringBuilder();
        builder.Append("Recommendation: ");
        builder.Append(Compact(result.Recommendation, 96));

        foreach (var signal in result.Signals)
        {
            builder.AppendLine();
            builder.Append(signal.Kind);
            builder.Append(": ");
            builder.Append(signal.Status);
            if (signal.EstimatedLatencyMs > 0)
            {
                builder.Append(" (~");
                builder.Append(signal.EstimatedLatencyMs);
                builder.Append("ms)");
            }

            if (!string.IsNullOrWhiteSpace(signal.Evidence))
            {
                builder.Append(" - ");
                builder.Append(Compact(signal.Evidence, 88));
            }
        }

        return builder.ToString();
    }

    public static string FormatConversationDiagnostics(UiaConversationDiagnosticsResult result)
    {
        ArgumentNullException.ThrowIfNull(result);

        var builder = new StringBuilder();
        builder.Append("Readiness: ");
        builder.Append(ConversationReadinessEvaluator.Evaluate(result));
        builder.AppendLine();
        builder.Append("Recommendation: ");
        builder.Append(Compact(result.Recommendation, 96));
        builder.AppendLine();
        builder.Append("Blocking dialogs: ");
        builder.Append(result.BlockingDialogs.Count);

        foreach (var dialog in result.BlockingDialogs.Take(2))
        {
            builder.AppendLine();
            builder.Append("- ");
            builder.Append(string.IsNullOrWhiteSpace(dialog.ClassName) ? "Dialog" : dialog.ClassName);
            if (!string.IsNullOrWhiteSpace(dialog.Message))
            {
                builder.Append(": ");
                builder.Append(Compact(dialog.Message, 80));
            }
        }

        builder.AppendLine();
        builder.Append("Conversations: ");
        builder.Append(result.Conversations.Count);

        foreach (var conversation in result.Conversations.Take(5))
        {
            builder.AppendLine();
            builder.Append("- ");
            builder.Append(Compact(conversation.Name, 72));
            if (conversation.IsSelected)
            {
                builder.Append(" [selected]");
            }

            if (conversation.HasUnreadHint)
            {
                builder.Append(" [unread]");
            }
        }

        return builder.ToString();
    }

    public static string FormatWindowDiagnostics(WindowCandidateDiagnosticsResult result)
    {
        ArgumentNullException.ThrowIfNull(result);

        var builder = new StringBuilder();
        builder.Append("Window: ");
        builder.Append(result.Health);
        builder.AppendLine();
        builder.Append("Selected: ");
        builder.Append(string.IsNullOrWhiteSpace(result.SelectedHwnd) ? "none" : result.SelectedHwnd);
        builder.AppendLine();
        builder.Append("Counts: total=");
        builder.Append(result.TotalDingTalkCandidates);
        builder.Append(" visible=");
        builder.Append(result.VisibleCandidates);
        builder.Append(" hidden=");
        builder.Append(result.HiddenWorkspaceCandidates);
        builder.Append(" dialogs=");
        builder.Append(result.BlockingDialogCandidates);
        builder.AppendLine();
        builder.Append("Recommendation: ");
        builder.Append(Compact(result.Recommendation, 96));
        if (result.RejectionReasonCounts.Count > 0)
        {
            builder.AppendLine();
            builder.Append("Reasons: ");
            builder.Append(string.Join(
                " ",
                result.RejectionReasonCounts
                    .Where(static pair => pair.Value > 0)
                    .OrderByDescending(static pair => pair.Value)
                    .ThenBy(static pair => pair.Key)
                    .Take(4)
                    .Select(static pair => pair.Key + "=" + pair.Value)));
        }

        foreach (var candidate in result.Candidates.Take(3))
        {
            builder.AppendLine();
            builder.Append("- ");
            builder.Append(candidate.Hwnd);
            builder.Append(" ");
            builder.Append(candidate.Decision);
            builder.Append("/");
            builder.Append(candidate.RejectionReason);
            builder.Append(" ");
            builder.Append(candidate.Width);
            builder.Append("x");
            builder.Append(candidate.Height);
            if (!string.IsNullOrWhiteSpace(candidate.ClassName))
            {
                builder.Append(" ");
                builder.Append(Compact(candidate.ClassName, 42));
            }
        }

        return builder.ToString();
    }

    public static string FormatLauncherDiagnostics(DingTalkLauncherDiagnosticsResult result)
    {
        ArgumentNullException.ThrowIfNull(result);

        var builder = new StringBuilder();
        builder.Append("Launcher: ");
        builder.Append(result.Readiness);
        builder.Append(" configured=");
        builder.Append(result.IsConfigured);
        builder.Append(" exists=");
        builder.Append(result.PathExists);
        if (result.RemoteDebuggingPort > 0)
        {
            builder.Append(" remoteDebug=");
            builder.Append(result.RemoteDebuggingPort);
        }

        if (result.RendererAccessibilityEnabled)
        {
            builder.Append(" rendererA11y=true");
        }

        builder.AppendLine();
        builder.Append("Recommendation: ");
        builder.Append(Compact(result.Recommendation, 96));
        if (!string.IsNullOrWhiteSpace(result.LauncherPath))
        {
            builder.AppendLine();
            builder.Append("Path: ");
            builder.Append(Compact(result.LauncherPath, 92));
        }

        return builder.ToString();
    }

    private static string Compact(string value, int maxLength)
    {
        var normalized = value.Replace("\r", " ", StringComparison.Ordinal)
            .Replace("\n", " ", StringComparison.Ordinal)
            .Trim();
        return normalized.Length <= maxLength
            ? normalized
            : normalized[..Math.Max(0, maxLength - 3)] + "...";
    }
}
