using DingTalkWindowsHost.Automation.WindowHost;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class WindowAttachmentJournalTests : IDisposable
{
    private readonly string _tempDirectory = Path.Combine(
        Path.GetTempPath(),
        "dingtalk-window-attachment-journal-tests",
        Guid.NewGuid().ToString("N"));

    [Fact]
    public void Save_and_load_round_trips_last_attachment()
    {
        var journal = new WindowAttachmentJournal(Path.Combine(_tempDirectory, "attachment.json"));
        var state = CreateState();

        journal.Save(state);
        var loaded = journal.Load();

        Assert.NotNull(loaded);
        Assert.Equal(state.ChildHandle, loaded!.ChildHandle);
        Assert.Equal(state.OriginalParentHandle, loaded.OriginalParentHandle);
        Assert.Equal(state.OriginalStyle, loaded.OriginalStyle);
        Assert.Equal(state.OriginalExStyle, loaded.OriginalExStyle);
    }

    [Fact]
    public void Clear_removes_saved_attachment()
    {
        var journal = new WindowAttachmentJournal(Path.Combine(_tempDirectory, "attachment.json"));
        journal.Save(CreateState());

        journal.Clear();

        Assert.Null(journal.Load());
    }

    [Fact]
    public void Load_returns_null_for_corrupt_journal()
    {
        var path = Path.Combine(_tempDirectory, "attachment.json");
        Directory.CreateDirectory(_tempDirectory);
        File.WriteAllText(path, "{not-json");
        var journal = new WindowAttachmentJournal(path);

        var loaded = journal.Load();

        Assert.Null(loaded);
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempDirectory))
        {
            Directory.Delete(_tempDirectory, recursive: true);
        }
    }

    private static EmbeddedWindowState CreateState()
    {
        return new EmbeddedWindowState(
            HostHandle: new IntPtr(0x701),
            ChildHandle: new IntPtr(0x601),
            OriginalParentHandle: new IntPtr(0x501),
            Bounds: new HostSurfaceBounds(1024, 720),
            AttachedAt: DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
            OriginalStyle: new IntPtr(0x1234),
            OriginalExStyle: new IntPtr(0x5678));
    }
}
