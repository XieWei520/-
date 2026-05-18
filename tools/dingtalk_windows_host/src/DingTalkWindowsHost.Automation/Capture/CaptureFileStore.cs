using System.Security.Cryptography;

namespace DingTalkWindowsHost.Automation.Capture;

public sealed class CaptureFileStore
{
    private readonly string _rootDirectory;

    public CaptureFileStore(string rootDirectory)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(rootDirectory);
        _rootDirectory = rootDirectory;
    }

    public async Task<CaptureFileStoreResult> SavePngAsync(
        byte[] pngBytes,
        DateTimeOffset capturedAt,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(pngBytes);
        if (pngBytes.Length == 0)
        {
            throw new ArgumentException("Screenshot bytes cannot be empty.", nameof(pngBytes));
        }

        var sha256 = Convert.ToHexString(SHA256.HashData(pngBytes)).ToLowerInvariant();
        var dayDirectory = Path.Combine(_rootDirectory, capturedAt.ToLocalTime().ToString("yyyyMMdd"));
        Directory.CreateDirectory(dayDirectory);
        var filePath = Path.Combine(dayDirectory, sha256 + ".png");
        if (!File.Exists(filePath))
        {
            await File.WriteAllBytesAsync(filePath, pngBytes, cancellationToken);
        }

        return new CaptureFileStoreResult(
            LocalImagePath: filePath,
            Sha256: sha256,
            BytesWritten: pngBytes.LongLength);
    }
}

public sealed record CaptureFileStoreResult(
    string LocalImagePath,
    string Sha256,
    long BytesWritten);
