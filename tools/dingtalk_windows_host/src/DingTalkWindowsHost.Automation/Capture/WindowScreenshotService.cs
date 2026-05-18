using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Contracts.Services;

namespace DingTalkWindowsHost.Automation.Capture;

public sealed class WindowScreenshotService : IWindowScreenshotService
{
    private readonly CaptureFileStore _fileStore;

    public WindowScreenshotService(CaptureFileStore fileStore)
    {
        ArgumentNullException.ThrowIfNull(fileStore);
        _fileStore = fileStore;
    }

    public async Task<WindowScreenshotResult?> CaptureAsync(
        IntPtr windowHandle,
        CancellationToken cancellationToken)
    {
        if (windowHandle == IntPtr.Zero || !GetWindowRect(windowHandle, out var rect))
        {
            return null;
        }

        var width = rect.Right - rect.Left;
        var height = rect.Bottom - rect.Top;
        if (width < 1 || height < 1)
        {
            return null;
        }

        using var bitmap = new Bitmap(width, height);
        using (var graphics = Graphics.FromImage(bitmap))
        {
            graphics.CopyFromScreen(rect.Left, rect.Top, 0, 0, new Size(width, height));
        }

        await using var stream = new MemoryStream();
        bitmap.Save(stream, ImageFormat.Png);
        var capturedAt = DateTimeOffset.UtcNow;
        var stored = await _fileStore.SavePngAsync(stream.ToArray(), capturedAt, cancellationToken);
        return new WindowScreenshotResult(
            LocalImagePath: stored.LocalImagePath,
            Sha256: stored.Sha256,
            Width: width,
            Height: height,
            BytesWritten: stored.BytesWritten,
            CapturedAt: capturedAt);
    }

    public async Task<WindowScreenshotResult?> CaptureChatAreaAsync(
        IntPtr windowHandle,
        CancellationToken cancellationToken)
    {
        if (windowHandle == IntPtr.Zero || !GetWindowRect(windowHandle, out var rect))
        {
            return null;
        }

        var width = rect.Right - rect.Left;
        var height = rect.Bottom - rect.Top;
        if (width < 1 || height < 1)
        {
            return null;
        }

        var crop = GetChatAreaCrop(width, height);
        using var bitmap = new Bitmap(crop.Width, crop.Height);
        using (var graphics = Graphics.FromImage(bitmap))
        {
            graphics.CopyFromScreen(
                rect.Left + crop.X,
                rect.Top + crop.Y,
                0,
                0,
                new Size(crop.Width, crop.Height));
        }

        if (ScreenshotBlankDetector.IsMostlyBlank(bitmap))
        {
            return null;
        }

        await using var stream = new MemoryStream();
        bitmap.Save(stream, ImageFormat.Png);
        var capturedAt = DateTimeOffset.UtcNow;
        var stored = await _fileStore.SavePngAsync(stream.ToArray(), capturedAt, cancellationToken);
        return new WindowScreenshotResult(
            LocalImagePath: stored.LocalImagePath,
            Sha256: stored.Sha256,
            Width: crop.Width,
            Height: crop.Height,
            BytesWritten: stored.BytesWritten,
            CapturedAt: capturedAt);
    }

    private static Rectangle GetChatAreaCrop(int width, int height)
    {
        var x = Math.Clamp((int)Math.Round(width * 0.30), 0, Math.Max(0, width - 1));
        var y = Math.Clamp((int)Math.Round(height * 0.12), 0, Math.Max(0, height - 1));
        var cropWidth = Math.Max(1, width - x);
        var cropHeight = Math.Max(1, Math.Min(height - y, (int)Math.Round(height * 0.68)));
        return new Rectangle(x, y, cropWidth, cropHeight);
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool GetWindowRect(IntPtr hWnd, out WindowRect lpRect);

    [StructLayout(LayoutKind.Sequential)]
    private readonly struct WindowRect
    {
        public readonly int Left;
        public readonly int Top;
        public readonly int Right;
        public readonly int Bottom;
    }
}
