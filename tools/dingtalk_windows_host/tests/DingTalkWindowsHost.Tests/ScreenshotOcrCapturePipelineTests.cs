using DingTalkWindowsHost.Automation.Capture;
using DingTalkWindowsHost.Automation.Ocr;
using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Contracts.Services;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class ScreenshotOcrCapturePipelineTests
{
    [Fact]
    public async Task CaptureAsync_returns_null_when_ocr_is_disabled()
    {
        var pipeline = new ScreenshotOcrCapturePipeline(
            new StaticScreenshotService(),
            new NullOcrService(),
            new EventNormalizer());

        var result = await pipeline.CaptureAsync(new IntPtr(0x1234), CancellationToken.None);

        Assert.Null(result);
    }

    [Fact]
    public async Task CaptureVisualChangeAsync_normalizes_chat_area_screenshot_without_ocr()
    {
        var pipeline = new ScreenshotOcrCapturePipeline(
            new StaticScreenshotService(),
            new NullOcrService(),
            new EventNormalizer());

        var result = await pipeline.CaptureVisualChangeAsync(new IntPtr(0x1234), CancellationToken.None);

        Assert.NotNull(result);
        Assert.Equal("capture.png", result!.LocalImagePath);
        Assert.Equal(CaptureSource.ChatAreaScreenshot, result.CaptureSource);
        Assert.Equal("VisualHash", result.SenderName);
        Assert.StartsWith("screenshot:", result.EventId, StringComparison.Ordinal);
        Assert.Contains("hash", result.Text, StringComparison.Ordinal);
    }

    [Fact]
    public async Task CaptureVisualChangeAsync_drops_unchanged_chat_area_hash()
    {
        var pipeline = new ScreenshotOcrCapturePipeline(
            new StaticScreenshotService(),
            new NullOcrService(),
            new EventNormalizer());

        var first = await pipeline.CaptureVisualChangeAsync(new IntPtr(0x1234), CancellationToken.None);
        var second = await pipeline.CaptureVisualChangeAsync(new IntPtr(0x1234), CancellationToken.None);

        Assert.NotNull(first);
        Assert.Null(second);
    }

    [Fact]
    public async Task CaptureAsync_normalizes_forwardable_ocr_text()
    {
        var pipeline = new ScreenshotOcrCapturePipeline(
            new StaticScreenshotService(),
            new StaticOcrService("  报警服务恢复正常  "),
            new EventNormalizer());

        var result = await pipeline.CaptureAsync(new IntPtr(0x1234), CancellationToken.None);

        Assert.NotNull(result);
        Assert.Equal("报警服务恢复正常", result!.Text);
        Assert.Equal("capture.png", result.LocalImagePath);
        Assert.Equal(CaptureSource.ChatAreaScreenshotOcr, result.CaptureSource);
        Assert.StartsWith("screenshot-ocr:", result.EventId, StringComparison.Ordinal);
    }

    [Fact]
    public async Task CaptureAsync_drops_ocr_noise()
    {
        var pipeline = new ScreenshotOcrCapturePipeline(
            new StaticScreenshotService(),
            new StaticOcrService("10:42"),
            new EventNormalizer());

        var result = await pipeline.CaptureAsync(new IntPtr(0x1234), CancellationToken.None);

        Assert.Null(result);
    }

    private sealed class StaticScreenshotService : IWindowScreenshotService
    {
        public Task<WindowScreenshotResult?> CaptureAsync(
            IntPtr windowHandle,
            CancellationToken cancellationToken)
        {
            return Task.FromResult<WindowScreenshotResult?>(new WindowScreenshotResult(
                LocalImagePath: "capture.png",
                Sha256: "hash",
                Width: 1024,
                Height: 720,
                BytesWritten: 42,
                CapturedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z")));
        }

        public Task<WindowScreenshotResult?> CaptureChatAreaAsync(
            IntPtr windowHandle,
            CancellationToken cancellationToken)
        {
            return CaptureAsync(windowHandle, cancellationToken);
        }
    }

    private sealed class StaticOcrService : IOcrService
    {
        private readonly string _text;

        public StaticOcrService(string text)
        {
            _text = text;
        }

        public bool IsEnabled => true;

        public Task<OcrResult?> RecognizeAsync(string imagePath, CancellationToken cancellationToken)
        {
            return Task.FromResult<OcrResult?>(new OcrResult(_text, Confidence: 0.91));
        }
    }
}
