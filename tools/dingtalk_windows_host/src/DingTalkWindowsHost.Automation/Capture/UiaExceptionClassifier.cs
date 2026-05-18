namespace DingTalkWindowsHost.Automation.Capture;

internal static class UiaExceptionClassifier
{
    public static bool IsTransient(Exception ex)
    {
        return ex is InvalidOperationException
            or TimeoutException
            or FlaUI.Core.Exceptions.PropertyNotSupportedException
            or System.Runtime.InteropServices.COMException
            || string.Equals(
                ex.GetType().Name,
                "ElementNotAvailableException",
                StringComparison.Ordinal);
    }
}
