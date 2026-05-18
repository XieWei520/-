using DingTalkWindowsHost.Automation.Ocr;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class ExternalCommandOcrServiceTests
{
    [Fact]
    public void FromEnvironment_returns_disabled_when_command_is_missing()
    {
        var service = ExternalCommandOcrService.FromEnvironment(static _ => null);

        Assert.False(service.IsEnabled);
    }

    [Fact]
    public async Task RecognizeAsync_returns_stdout_text_when_command_succeeds()
    {
        var service = new ExternalCommandOcrService(
            commandPath: "ocr.exe",
            argumentsTemplate: "--image {image}",
            timeout: TimeSpan.FromSeconds(2),
            runProcess: (fileName, arguments, timeout, cancellationToken) =>
                Task.FromResult(new ExternalCommandOcrProcessResult(
                    ExitCode: 0,
                    StandardOutput: "  message text  ",
                    StandardError: string.Empty,
                    TimedOut: false)));

        var result = await service.RecognizeAsync(@"C:\captures\chat.png", CancellationToken.None);

        Assert.NotNull(result);
        Assert.Equal("message text", result!.Text);
        Assert.Equal(0.5, result.Confidence);
    }

    [Fact]
    public async Task RecognizeAsync_returns_null_when_command_fails()
    {
        var service = new ExternalCommandOcrService(
            commandPath: "ocr.exe",
            argumentsTemplate: "{image}",
            timeout: TimeSpan.FromSeconds(2),
            runProcess: (fileName, arguments, timeout, cancellationToken) =>
                Task.FromResult(new ExternalCommandOcrProcessResult(
                    ExitCode: 1,
                    StandardOutput: "secret failure output",
                    StandardError: "failed",
                    TimedOut: false)));

        var result = await service.RecognizeAsync(@"C:\captures\chat.png", CancellationToken.None);

        Assert.Null(result);
    }

    [Fact]
    public async Task RecognizeAsync_quotes_image_path_in_arguments_template()
    {
        string? capturedArguments = null;
        var service = new ExternalCommandOcrService(
            commandPath: "ocr.exe",
            argumentsTemplate: "--image={image}",
            timeout: TimeSpan.FromSeconds(2),
            runProcess: (fileName, arguments, timeout, cancellationToken) =>
            {
                capturedArguments = arguments;
                return Task.FromResult(new ExternalCommandOcrProcessResult(
                    ExitCode: 0,
                    StandardOutput: "message",
                    StandardError: string.Empty,
                    TimedOut: false));
            });

        await service.RecognizeAsync(@"C:\captures\chat area.png", CancellationToken.None);

        Assert.Equal("--image=\"C:\\captures\\chat area.png\"", capturedArguments);
    }

    [Fact]
    public async Task RecognizeAsync_passes_configured_environment_variables_to_runner()
    {
        IReadOnlyDictionary<string, string>? capturedEnvironment = null;
        var service = new ExternalCommandOcrService(
            commandPath: "ocr.exe",
            argumentsTemplate: "{image}",
            timeout: TimeSpan.FromSeconds(2),
            environmentVariables: new Dictionary<string, string>
            {
                ["TESSDATA_PREFIX"] = @"C:\runtime\tessdata",
            },
            runProcess: (fileName, arguments, timeout, environmentVariables, cancellationToken) =>
            {
                capturedEnvironment = environmentVariables;
                return Task.FromResult(new ExternalCommandOcrProcessResult(
                    ExitCode: 0,
                    StandardOutput: "message",
                    StandardError: string.Empty,
                    TimedOut: false));
            });

        await service.RecognizeAsync(@"C:\captures\chat.png", CancellationToken.None);

        Assert.NotNull(capturedEnvironment);
        Assert.Equal(@"C:\runtime\tessdata", capturedEnvironment!["TESSDATA_PREFIX"]);
    }
}
