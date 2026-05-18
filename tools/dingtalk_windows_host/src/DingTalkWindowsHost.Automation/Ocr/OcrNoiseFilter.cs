namespace DingTalkWindowsHost.Automation.Ocr;

public static class OcrNoiseFilter
{
    public static bool IsForwardable(string text)
    {
        var normalized = Normalize(text);
        if (normalized.Length < 2)
        {
            return false;
        }

        return !IsClockText(normalized)
            && !IsKnownChromeOrDingTalkNoise(normalized);
    }

    public static string Normalize(string text)
    {
        return string.Join(' ', text.Split(Array.Empty<char>(), StringSplitOptions.RemoveEmptyEntries));
    }

    private static bool IsKnownChromeOrDingTalkNoise(string text)
    {
        return text.Equals("DingTalk", StringComparison.OrdinalIgnoreCase)
            || text.Equals("\u9489\u9489", StringComparison.OrdinalIgnoreCase)
            || text.Equals("\u6d88\u606f", StringComparison.OrdinalIgnoreCase)
            || text.Contains("\u52a0\u8f7d\u4e2d", StringComparison.OrdinalIgnoreCase)
            || text.Contains("Loading", StringComparison.OrdinalIgnoreCase);
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
}
