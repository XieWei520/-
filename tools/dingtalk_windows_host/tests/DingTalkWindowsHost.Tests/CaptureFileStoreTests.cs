using DingTalkWindowsHost.Automation.Capture;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class CaptureFileStoreTests : IDisposable
{
    private readonly string _tempDirectory = Path.Combine(
        Path.GetTempPath(),
        "dingtalk-capture-store-tests",
        Guid.NewGuid().ToString("N"));

    [Fact]
    public async Task SavePngAsync_dedupes_by_sha256()
    {
        var store = new CaptureFileStore(_tempDirectory);
        var bytes = new byte[] { 137, 80, 78, 71, 1, 2, 3 };
        var capturedAt = DateTimeOffset.Parse("2026-05-15T10:00:00Z");

        var first = await store.SavePngAsync(bytes, capturedAt, CancellationToken.None);
        var second = await store.SavePngAsync(bytes, capturedAt, CancellationToken.None);

        Assert.Equal(first.Sha256, second.Sha256);
        Assert.Equal(first.LocalImagePath, second.LocalImagePath);
        Assert.True(File.Exists(first.LocalImagePath));
        Assert.Single(Directory.GetFiles(_tempDirectory, "*.png", SearchOption.AllDirectories));
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempDirectory))
        {
            Directory.Delete(_tempDirectory, recursive: true);
        }
    }
}
