using DingTalkWindowsHost.Automation.Capture;
using DingTalkWindowsHost.Automation.Ocr;
using DingTalkWindowsHost.Automation.WindowHost;
using DingTalkWindowsHost.Contracts.Services;

namespace DingTalkWindowsHost.Automation;

public sealed class HostAutomation
{
    public HostAutomation(IWindowScreenshotService screenshotService)
        : this(screenshotService, new NullOcrService(), WindowAttachmentJournal.Disabled)
    {
    }

    public HostAutomation(IWindowScreenshotService screenshotService, IOcrService ocrService)
        : this(screenshotService, ocrService, WindowAttachmentJournal.Disabled)
    {
    }

    public HostAutomation(
        IWindowScreenshotService screenshotService,
        IOcrService ocrService,
        WindowAttachmentJournal windowAttachmentJournal)
    {
        ArgumentNullException.ThrowIfNull(screenshotService);
        ArgumentNullException.ThrowIfNull(ocrService);
        ArgumentNullException.ThrowIfNull(windowAttachmentJournal);

        WindowLocator = new DingTalkWindowLocator();
        WindowEmbedder = new NativeWindowEmbedder(windowAttachmentJournal);
        WindowSupervisor = new WindowSupervisor(WindowLocator, WindowEmbedder);
        ChatSurfaceProbe = new UiaChatSurfaceProbe();
        ClipboardMessageProbe = new ClipboardMessageProbe(ClipboardMessageProbeOptions.FromEnvironment());
        MessageProbeCoordinator = new UiaMessageProbeCoordinator(
            WindowLocator,
            ChatSurfaceProbe,
            () => WindowSupervisor.LastSnapshot.CurrentHwnd,
            handle => ToExtractedMessage(ClipboardMessageProbe.ProbeLatest(handle)));
        EventNormalizer = new EventNormalizer();
        ScreenshotOcrCapturePipeline = new ScreenshotOcrCapturePipeline(
            screenshotService,
            ocrService,
            EventNormalizer);
    }

    public DingTalkWindowLocator WindowLocator { get; }

    public NativeWindowEmbedder WindowEmbedder { get; }

    public WindowSupervisor WindowSupervisor { get; }

    public UiaChatSurfaceProbe ChatSurfaceProbe { get; }

    public ClipboardMessageProbe ClipboardMessageProbe { get; }

    public UiaMessageProbeCoordinator MessageProbeCoordinator { get; }

    public EventNormalizer EventNormalizer { get; }

    public ScreenshotOcrCapturePipeline ScreenshotOcrCapturePipeline { get; }

    private static ExtractedMessage? ToExtractedMessage(
        DingTalkWindowsHost.Contracts.Services.ExtractedClipboardMessage? message)
    {
        return message is null
            ? null
            : new ExtractedMessage(
                SourceConversationName: message.SourceConversationName,
                SenderName: message.SenderName,
                Text: message.Text,
                ObservedAt: message.ObservedAt,
                SourceConversationIdHint: message.SourceConversationIdHint);
    }
}
