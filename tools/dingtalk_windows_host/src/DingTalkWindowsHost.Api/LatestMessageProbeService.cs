using DingTalkWindowsHost.Contracts.Models;
using DingTalkWindowsHost.Contracts.Services;
using DingTalkWindowsHost.Storage.Repositories;

namespace DingTalkWindowsHost.Api;

public sealed class LatestMessageProbeService
{
    private readonly IClipboardMessageProbe _clipboardMessageProbe;
    private readonly ILatestMessageProbe _latestMessageProbe;
    private readonly RawEventsRepository _rawEventsRepository;

    public LatestMessageProbeService(
        IClipboardMessageProbe clipboardMessageProbe,
        ILatestMessageProbe latestMessageProbe,
        RawEventsRepository rawEventsRepository)
    {
        ArgumentNullException.ThrowIfNull(clipboardMessageProbe);
        ArgumentNullException.ThrowIfNull(latestMessageProbe);
        ArgumentNullException.ThrowIfNull(rawEventsRepository);

        _clipboardMessageProbe = clipboardMessageProbe;
        _latestMessageProbe = latestMessageProbe;
        _rawEventsRepository = rawEventsRepository;
    }

    public async Task<LatestMessageProbeResult> ProbeLatestAsync(
        IntPtr windowHandle,
        CancellationToken cancellationToken)
    {
        var coordinatedMessage = TryProbeCoordinatedLatest();
        if (coordinatedMessage is not null)
        {
            var coordinatedEvent = NormalizeLatestMessage(coordinatedMessage);
            if (coordinatedEvent is not null)
            {
                await _rawEventsRepository.UpsertAsync(coordinatedEvent, cancellationToken);
                return LatestMessageProbeResult.Stored(coordinatedEvent, FormatHandle(windowHandle));
            }
        }

        if (windowHandle == IntPtr.Zero)
        {
            return LatestMessageProbeResult.NoWindow(DateTimeOffset.UtcNow);
        }

        var message = _clipboardMessageProbe.ProbeLatest(windowHandle);
        if (message is null)
        {
            return LatestMessageProbeResult.NoMessage(DateTimeOffset.UtcNow, FormatHandle(windowHandle));
        }

        var observedEvent = NormalizeClipboardMessage(message);
        if (observedEvent is null)
        {
            return LatestMessageProbeResult.NoMessage(DateTimeOffset.UtcNow, FormatHandle(windowHandle));
        }

        await _rawEventsRepository.UpsertAsync(observedEvent, cancellationToken);
        return LatestMessageProbeResult.Stored(observedEvent, FormatHandle(windowHandle));
    }

    private LatestProbeMessage? TryProbeCoordinatedLatest()
    {
        try
        {
            return _latestMessageProbe.ProbeLatest();
        }
        catch (Exception)
        {
            return null;
        }
    }

    private DingTalkObservedEvent? NormalizeLatestMessage(LatestProbeMessage message)
    {
        return DingTalkEventNormalizer.Normalize(
            message.SourceConversationName,
            message.SenderName,
            message.Text,
            message.ObservedAt,
            message.LocalImagePath,
            message.CaptureSource,
            message.SourceConversationIdHint);
    }

    private DingTalkObservedEvent? NormalizeClipboardMessage(ExtractedClipboardMessage message)
    {
        return DingTalkEventNormalizer.Normalize(
            message.SourceConversationName,
            message.SenderName,
            message.Text,
            message.ObservedAt,
            sourceConversationIdHint: message.SourceConversationIdHint);
    }

    private static string FormatHandle(IntPtr handle)
    {
        return handle == IntPtr.Zero ? "0x0" : "0x" + handle.ToInt64().ToString("X");
    }
}

public sealed record LatestMessageProbeResult(
    string Status,
    string TargetHwnd,
    string EventId,
    string ContentHash,
    int TextLength,
    string SourceConversationId,
    DateTimeOffset ObservedAt)
{
    public static LatestMessageProbeResult Stored(DingTalkObservedEvent observedEvent, string targetHwnd)
    {
        return new LatestMessageProbeResult(
            Status: "Stored",
            TargetHwnd: targetHwnd,
            EventId: observedEvent.EventId,
            ContentHash: observedEvent.ContentHash,
            TextLength: observedEvent.Text.Length,
            SourceConversationId: observedEvent.SourceConversationId,
            ObservedAt: observedEvent.ObservedAt);
    }

    public static LatestMessageProbeResult NoWindow(DateTimeOffset observedAt)
    {
        return new LatestMessageProbeResult(
            Status: "NoWindow",
            TargetHwnd: string.Empty,
            EventId: string.Empty,
            ContentHash: string.Empty,
            TextLength: 0,
            SourceConversationId: string.Empty,
            ObservedAt: observedAt);
    }

    public static LatestMessageProbeResult NoMessage(DateTimeOffset observedAt, string targetHwnd)
    {
        return new LatestMessageProbeResult(
            Status: "NoMessage",
            TargetHwnd: targetHwnd,
            EventId: string.Empty,
            ContentHash: string.Empty,
            TextLength: 0,
            SourceConversationId: string.Empty,
            ObservedAt: observedAt);
    }
}
