using System.Security.Cryptography;
using System.Text;

namespace DingTalkWindowsHost.Contracts.Models;

public static class DingTalkEventNormalizer
{
    public const string ClipboardActiveSourceConversationId = "windows:clipboard-active";

    public static DingTalkObservedEvent? Normalize(
        string sourceConversationNameValue,
        string senderNameValue,
        string textValue,
        DateTimeOffset observedAt,
        string localImagePathValue = "",
        CaptureSource captureSource = CaptureSource.UiaText,
        string sourceConversationIdHint = "")
    {
        var sourceConversationName = NormalizeWhitespace(sourceConversationNameValue);
        var senderName = NormalizeWhitespace(senderNameValue);
        var text = NormalizeWhitespace(textValue);

        if (string.IsNullOrWhiteSpace(text)
            || text.StartsWith("__DINGTALK_HOST_CLIPBOARD_PROBE__", StringComparison.Ordinal))
        {
            return null;
        }

        if (IsSystemBlockerText(sourceConversationName, senderName, text))
        {
            return null;
        }

        var embeddedSourceName = ExtractEmbeddedSourceName(ref text);
        var localImagePath = NormalizeWhitespace(localImagePathValue);
        var contentHash = Sha256Hex(text + "|" + localImagePath + "|" + captureSource);
        var sourceConversationId = string.IsNullOrWhiteSpace(sourceConversationIdHint)
            ? BuildSourceConversationId(sourceConversationName, captureSource)
            : NormalizeWhitespace(sourceConversationIdHint);
        if (string.IsNullOrWhiteSpace(sourceConversationId))
        {
            return null;
        }

        var timestampBucket = BucketToMinute(observedAt)
            .ToUniversalTime()
            .ToString("yyyyMMddHHmm");
        var identityHashInput = IsClipboardFallbackSource(sourceConversationId)
            ? sourceConversationId + "|" + senderName + "|" + contentHash
            : sourceConversationId + "|" + senderName + "|" + timestampBucket;
        var eventId = string.Join(
            ':',
            EventIdPrefix(captureSource),
            Sha256Hex(identityHashInput).AsSpan(0, 16).ToString(),
            contentHash);

        return new DingTalkObservedEvent(
            EventId: eventId,
            SourceConversationId: sourceConversationId,
            SourceConversationName: sourceConversationName,
            EmbeddedSourceName: embeddedSourceName,
            SenderName: senderName,
            ObservedAt: observedAt,
            Text: text,
            LocalImagePath: localImagePath,
            CaptureSource: captureSource,
            ContentHash: contentHash);
    }

    private static string EventIdPrefix(CaptureSource captureSource)
    {
        return captureSource switch
        {
            CaptureSource.UiaText => "uia-text",
            CaptureSource.UiaImageMetadata => "uia-image",
            CaptureSource.PreviewSave => "preview-save",
            CaptureSource.ChatAreaScreenshot => "screenshot",
            CaptureSource.ChatAreaScreenshotOcr => "screenshot-ocr",
            _ => "capture",
        };
    }

    private static bool IsSystemBlockerText(
        string sourceConversationName,
        string senderName,
        string text)
    {
        if (!string.IsNullOrWhiteSpace(sourceConversationName)
            || !string.IsNullOrWhiteSpace(senderName))
        {
            return false;
        }

        return text.Contains("\u5f53\u524d\u68c0\u6d4b\u51fa\u9489\u9489\u5f02\u5e38", StringComparison.OrdinalIgnoreCase)
            || text.Contains("\u6e05\u7406\u672c\u5730\u7f13\u5b58", StringComparison.OrdinalIgnoreCase)
            || text.Contains("\u9489\u9489\u5b89\u5168\u6a21\u5f0f", StringComparison.OrdinalIgnoreCase)
            || text.Contains("Resolve blocking dialog before capture", StringComparison.OrdinalIgnoreCase)
            || text.Contains("login-required:", StringComparison.OrdinalIgnoreCase)
            || text.Contains("blocked-by-overlay:", StringComparison.OrdinalIgnoreCase)
            || text.Contains("conversation-diagnostics-error", StringComparison.OrdinalIgnoreCase);
    }

    private static string ExtractEmbeddedSourceName(ref string text)
    {
        if (!text.StartsWith("[", StringComparison.Ordinal))
        {
            return string.Empty;
        }

        var closingIndex = text.IndexOf("]", StringComparison.Ordinal);
        if (closingIndex <= 1)
        {
            return string.Empty;
        }

        var embeddedSourceName = NormalizeWhitespace(text[1..closingIndex]);
        text = NormalizeWhitespace(text[(closingIndex + 1)..]);
        return embeddedSourceName;
    }

    private static DateTimeOffset BucketToMinute(DateTimeOffset value)
    {
        return new DateTimeOffset(
            value.Year,
            value.Month,
            value.Day,
            value.Hour,
            value.Minute,
            0,
            value.Offset);
    }

    private static string NormalizeWhitespace(string value)
    {
        return string.Join(' ', value.Split(Array.Empty<char>(), StringSplitOptions.RemoveEmptyEntries));
    }

    private static string BuildSourceConversationId(
        string sourceConversationName,
        CaptureSource captureSource)
    {
        if (string.IsNullOrWhiteSpace(sourceConversationName))
        {
            return "source:unknown";
        }

        if (captureSource == CaptureSource.UiaText)
        {
            return "windows:" + Sha256Hex("dingtalk|" + sourceConversationName)[..8];
        }

        return "source:" + Slug(sourceConversationName);
    }

    private static string Slug(string value)
    {
        var normalized = NormalizeWhitespace(value).ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(normalized))
        {
            return "unknown";
        }

        var builder = new StringBuilder(normalized.Length);
        var previousWasDash = false;

        foreach (var ch in normalized)
        {
            if (char.IsLetterOrDigit(ch))
            {
                builder.Append(ch);
                previousWasDash = false;
                continue;
            }

            if (!previousWasDash)
            {
                builder.Append('-');
                previousWasDash = true;
            }
        }

        return builder.ToString().Trim('-');
    }

    private static bool IsClipboardFallbackSource(string sourceConversationId)
    {
        return string.Equals(
            sourceConversationId,
            ClipboardActiveSourceConversationId,
            StringComparison.OrdinalIgnoreCase);
    }

    private static string Sha256Hex(string value)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(value));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}
