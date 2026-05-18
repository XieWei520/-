using System.Text.Json;

namespace DingTalkWindowsHost.Automation.WindowHost;

public sealed class WindowAttachmentJournal
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
    };

    private readonly string _journalPath;

    public WindowAttachmentJournal(string journalPath)
    {
        ArgumentNullException.ThrowIfNull(journalPath);
        _journalPath = journalPath;
    }

    public static WindowAttachmentJournal Disabled { get; } = new(string.Empty);

    public void Save(EmbeddedWindowState state)
    {
        if (string.IsNullOrWhiteSpace(_journalPath))
        {
            return;
        }

        var directory = Path.GetDirectoryName(Path.GetFullPath(_journalPath));
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }

        var record = WindowAttachmentJournalRecord.FromState(state);
        File.WriteAllText(_journalPath, JsonSerializer.Serialize(record, JsonOptions));
    }

    public EmbeddedWindowState? Load()
    {
        if (string.IsNullOrWhiteSpace(_journalPath) || !File.Exists(_journalPath))
        {
            return null;
        }

        try
        {
            var record = JsonSerializer.Deserialize<WindowAttachmentJournalRecord>(
                File.ReadAllText(_journalPath),
                JsonOptions);
            return record?.ToState();
        }
        catch (JsonException)
        {
            return null;
        }
        catch (IOException)
        {
            return null;
        }
        catch (UnauthorizedAccessException)
        {
            return null;
        }
    }

    public void Clear()
    {
        if (string.IsNullOrWhiteSpace(_journalPath) || !File.Exists(_journalPath))
        {
            return;
        }

        File.Delete(_journalPath);
    }

    private sealed record WindowAttachmentJournalRecord(
        long HostHandle,
        long ChildHandle,
        long OriginalParentHandle,
        int Width,
        int Height,
        DateTimeOffset AttachedAt,
        long OriginalStyle,
        long OriginalExStyle)
    {
        public static WindowAttachmentJournalRecord FromState(EmbeddedWindowState state)
        {
            return new WindowAttachmentJournalRecord(
                HostHandle: state.HostHandle.ToInt64(),
                ChildHandle: state.ChildHandle.ToInt64(),
                OriginalParentHandle: state.OriginalParentHandle.ToInt64(),
                Width: state.Bounds.Width,
                Height: state.Bounds.Height,
                AttachedAt: state.AttachedAt,
                OriginalStyle: state.OriginalStyle.ToInt64(),
                OriginalExStyle: state.OriginalExStyle.ToInt64());
        }

        public EmbeddedWindowState ToState()
        {
            return new EmbeddedWindowState(
                HostHandle: new IntPtr(HostHandle),
                ChildHandle: new IntPtr(ChildHandle),
                OriginalParentHandle: new IntPtr(OriginalParentHandle),
                Bounds: new HostSurfaceBounds(Width, Height),
                AttachedAt: AttachedAt,
                OriginalStyle: new IntPtr(OriginalStyle),
                OriginalExStyle: new IntPtr(OriginalExStyle));
        }
    }
}
