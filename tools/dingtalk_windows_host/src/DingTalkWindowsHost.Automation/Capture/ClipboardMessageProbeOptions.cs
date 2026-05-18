namespace DingTalkWindowsHost.Automation.Capture;

public sealed record ClipboardMessageProbeOptions(bool Enabled)
{
    public static ClipboardMessageProbeOptions FromEnvironment()
    {
        var raw = Environment.GetEnvironmentVariable("DINGTALK_HOST_ENABLE_CLIPBOARD_PROBE");
        return new ClipboardMessageProbeOptions(IsTruthy(raw));
    }

    private static bool IsTruthy(string? value)
    {
        var normalized = value?.Trim().ToLowerInvariant();
        return normalized is "1" or "true" or "yes" or "on";
    }
}
