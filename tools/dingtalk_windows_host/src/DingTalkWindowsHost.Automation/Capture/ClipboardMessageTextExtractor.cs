namespace DingTalkWindowsHost.Automation.Capture;

public static class ClipboardMessageTextExtractor
{
    private const string ProbeSentinelPrefix = "__DINGTALK_HOST_CLIPBOARD_PROBE__";

    private static readonly string[] ExactNoiseTexts =
    {
        "DingTalk",
        "\u9489\u9489",
    };

    private static readonly string[] ContainsNoiseTexts =
    {
        "Enter/Alt+S",
        "Ctrl+Enter",
        "\u6d88\u606f",
        "\u6587\u6863",
        "AI \u542c\u8bb0",
        "\u641c\u7d22\u6216\u63d0\u95ee",
    };

    public static string? TryExtractLatest(string clipboardText, string sentinelText)
    {
        var normalizedSentinel = NormalizeLine(sentinelText);
        if (string.IsNullOrWhiteSpace(clipboardText))
        {
            return null;
        }

        var lines = clipboardText
            .Split(new[] { "\r\n", "\n", "\r" }, StringSplitOptions.None)
            .Select(NormalizeLine)
            .Where(line => !string.IsNullOrWhiteSpace(line))
            .ToArray();

        for (var index = lines.Length - 1; index >= 0; index--)
        {
            var line = lines[index];
            if (line.Equals(normalizedSentinel, StringComparison.Ordinal)
                || IsLikelyNoise(line))
            {
                continue;
            }

            return line;
        }

        return null;
    }

    private static bool IsLikelyNoise(string text)
    {
        return text.StartsWith(ProbeSentinelPrefix, StringComparison.Ordinal)
            || ExactNoiseTexts.Any(noise => text.Equals(noise, StringComparison.OrdinalIgnoreCase))
            || ContainsNoiseTexts.Any(noise => text.Contains(noise, StringComparison.OrdinalIgnoreCase))
            || IsClockText(text);
    }

    private static bool IsClockText(string text)
    {
        if (text.Length is < 4 or > 5)
        {
            return false;
        }

        var separatorIndex = text.IndexOf(':', StringComparison.Ordinal);
        return separatorIndex is 1 or 2
            && int.TryParse(text[..separatorIndex], out _)
            && int.TryParse(text[(separatorIndex + 1)..], out _);
    }

    private static string NormalizeLine(string value)
    {
        return string.Join(' ', value.Split(Array.Empty<char>(), StringSplitOptions.RemoveEmptyEntries));
    }
}
