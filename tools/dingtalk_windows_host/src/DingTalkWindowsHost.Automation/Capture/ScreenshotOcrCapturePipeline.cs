using DingTalkWindowsHost.Automation.Ocr;
using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Contracts.Services;

namespace DingTalkWindowsHost.Automation.Capture;

public sealed class ScreenshotOcrCapturePipeline
{
    private readonly EventNormalizer _eventNormalizer;
    private readonly IOcrService _ocrService;
    private readonly IWindowScreenshotService _screenshotService;
    private string _lastVisualChangeSha256 = string.Empty;

    public ScreenshotOcrCapturePipeline(
        IWindowScreenshotService screenshotService,
        IOcrService ocrService,
        EventNormalizer eventNormalizer)
    {
        ArgumentNullException.ThrowIfNull(screenshotService);
        ArgumentNullException.ThrowIfNull(ocrService);
        ArgumentNullException.ThrowIfNull(eventNormalizer);

        _screenshotService = screenshotService;
        _ocrService = ocrService;
        _eventNormalizer = eventNormalizer;
    }

    public bool IsEnabled => _ocrService.IsEnabled;

    public async Task<DingTalkObservedEvent?> CaptureVisualChangeAsync(
        IntPtr windowHandle,
        CancellationToken cancellationToken)
    {
        if (windowHandle == IntPtr.Zero)
        {
            return null;
        }

        var screenshot = await _screenshotService.CaptureChatAreaAsync(windowHandle, cancellationToken);
        if (screenshot is null
            || string.Equals(screenshot.Sha256, _lastVisualChangeSha256, StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        _lastVisualChangeSha256 = screenshot.Sha256;
        var shortHash = screenshot.Sha256.Length <= 12
            ? screenshot.Sha256
            : screenshot.Sha256[..12];
        var message = new ExtractedMessage(
            SourceConversationName: "DingTalk Screenshot",
            SenderName: "VisualHash",
            Text: "Chat area visual change " + shortHash,
            ObservedAt: screenshot.CapturedAt,
            LocalImagePath: screenshot.LocalImagePath,
            CaptureSource: CaptureSource.ChatAreaScreenshot);

        return _eventNormalizer.Normalize(message);
    }

    public async Task<DingTalkObservedEvent?> CaptureAsync(
        IntPtr windowHandle,
        CancellationToken cancellationToken)
    {
        if (!IsEnabled || windowHandle == IntPtr.Zero)
        {
            return null;
        }

        var screenshot = await _screenshotService.CaptureAsync(windowHandle, cancellationToken);
        if (screenshot is null)
        {
            return null;
        }

        var ocr = await _ocrService.RecognizeAsync(screenshot.LocalImagePath, cancellationToken);
        if (ocr is null || !OcrNoiseFilter.IsForwardable(ocr.Text))
        {
            return null;
        }

        var message = new ExtractedMessage(
            SourceConversationName: "DingTalk Screenshot",
            SenderName: "OCR",
            Text: OcrNoiseFilter.Normalize(ocr.Text),
            ObservedAt: screenshot.CapturedAt,
            LocalImagePath: screenshot.LocalImagePath,
            CaptureSource: CaptureSource.ChatAreaScreenshotOcr);

        return _eventNormalizer.Normalize(message);
    }
}
