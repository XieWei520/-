namespace DingTalkWindowsHost.Automation.Ocr;

public sealed record OcrResult(
    string Text,
    double Confidence);
