namespace DingTalkWindowsHost.Automation.Ocr;

public interface IOcrService
{
    bool IsEnabled { get; }

    Task<OcrResult?> RecognizeAsync(string imagePath, CancellationToken cancellationToken);
}
