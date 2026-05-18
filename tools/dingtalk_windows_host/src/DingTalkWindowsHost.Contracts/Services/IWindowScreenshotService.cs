using DingTalkWindowsHost.Contracts.Models;

namespace DingTalkWindowsHost.Contracts.Services;

public interface IWindowScreenshotService
{
    Task<WindowScreenshotResult?> CaptureAsync(IntPtr windowHandle, CancellationToken cancellationToken);

    Task<WindowScreenshotResult?> CaptureChatAreaAsync(IntPtr windowHandle, CancellationToken cancellationToken);
}
