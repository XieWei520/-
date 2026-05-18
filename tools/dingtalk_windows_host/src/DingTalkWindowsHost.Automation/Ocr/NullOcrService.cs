namespace DingTalkWindowsHost.Automation.Ocr;

public sealed class NullOcrService : IOcrService
{
    public bool IsEnabled => false;

    public Task<OcrResult?> RecognizeAsync(string imagePath, CancellationToken cancellationToken)
    {
        return Task.FromResult<OcrResult?>(null);
    }
}
