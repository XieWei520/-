using System.Diagnostics;

namespace DingTalkWindowsHost.Automation.Ocr;

public sealed record ExternalCommandOcrProcessResult(
    int ExitCode,
    string StandardOutput,
    string StandardError,
    bool TimedOut);

public sealed class ExternalCommandOcrService : IOcrService
{
    private const string DefaultArgumentsTemplate = "{image}";
    private static readonly TimeSpan DefaultTimeout = TimeSpan.FromSeconds(8);

    private readonly string _argumentsTemplate;
    private readonly string _commandPath;
    private readonly IReadOnlyDictionary<string, string> _environmentVariables;
    private readonly Func<string, string, TimeSpan, IReadOnlyDictionary<string, string>, CancellationToken, Task<ExternalCommandOcrProcessResult>> _runProcess;
    private readonly TimeSpan _timeout;

    public ExternalCommandOcrService(
        string commandPath,
        string argumentsTemplate,
        TimeSpan timeout,
        Func<string, string, TimeSpan, CancellationToken, Task<ExternalCommandOcrProcessResult>> runProcess)
        : this(
            commandPath,
            argumentsTemplate,
            timeout,
            new Dictionary<string, string>(),
            (fileName, arguments, commandTimeout, environmentVariables, cancellationToken) =>
                runProcess(fileName, arguments, commandTimeout, cancellationToken))
    {
    }

    public ExternalCommandOcrService(
        string commandPath,
        string argumentsTemplate,
        TimeSpan timeout,
        IReadOnlyDictionary<string, string> environmentVariables,
        Func<string, string, TimeSpan, IReadOnlyDictionary<string, string>, CancellationToken, Task<ExternalCommandOcrProcessResult>> runProcess)
    {
        ArgumentNullException.ThrowIfNull(runProcess);
        ArgumentNullException.ThrowIfNull(environmentVariables);

        _commandPath = commandPath;
        _argumentsTemplate = string.IsNullOrWhiteSpace(argumentsTemplate)
            ? DefaultArgumentsTemplate
            : argumentsTemplate;
        _timeout = timeout <= TimeSpan.Zero ? DefaultTimeout : timeout;
        _environmentVariables = environmentVariables;
        _runProcess = runProcess;
    }

    public bool IsEnabled => !string.IsNullOrWhiteSpace(_commandPath);

    public static IOcrService FromEnvironment()
    {
        return FromEnvironment(Environment.GetEnvironmentVariable);
    }

    internal static IOcrService FromEnvironment(Func<string, string?> environmentVariableSource)
    {
        ArgumentNullException.ThrowIfNull(environmentVariableSource);

        var command = environmentVariableSource("DINGTALK_HOST_OCR_COMMAND");
        if (string.IsNullOrWhiteSpace(command))
        {
            return new NullOcrService();
        }

        var argumentsTemplate = environmentVariableSource("DINGTALK_HOST_OCR_ARGUMENTS")
            ?? DefaultArgumentsTemplate;
        var ocrEnvironment = ParseEnvironmentVariables(
            environmentVariableSource("DINGTALK_HOST_OCR_ENV"));
        var timeout = int.TryParse(
                environmentVariableSource("DINGTALK_HOST_OCR_TIMEOUT_SECONDS"),
                out var seconds)
            && seconds is > 0 and <= 60
                ? TimeSpan.FromSeconds(seconds)
                : DefaultTimeout;

        return new ExternalCommandOcrService(
            command,
            argumentsTemplate,
            timeout,
            ocrEnvironment,
            RunProcessAsync);
    }

    public async Task<OcrResult?> RecognizeAsync(string imagePath, CancellationToken cancellationToken)
    {
        if (!IsEnabled || string.IsNullOrWhiteSpace(imagePath))
        {
            return null;
        }

        var arguments = _argumentsTemplate.Replace(
            "{image}",
            QuoteArgument(imagePath),
            StringComparison.Ordinal);
        var result = await _runProcess(
            _commandPath,
            arguments,
            _timeout,
            _environmentVariables,
            cancellationToken);
        if (result.TimedOut || result.ExitCode != 0)
        {
            return null;
        }

        var text = result.StandardOutput.Trim();
        return string.IsNullOrWhiteSpace(text)
            ? null
            : new OcrResult(text, Confidence: 0.5);
    }

    private static async Task<ExternalCommandOcrProcessResult> RunProcessAsync(
        string fileName,
        string arguments,
        TimeSpan timeout,
        IReadOnlyDictionary<string, string> environmentVariables,
        CancellationToken cancellationToken)
    {
        using var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = fileName,
                Arguments = arguments,
                CreateNoWindow = true,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
            },
        };
        foreach (var (key, value) in environmentVariables)
        {
            process.StartInfo.Environment[key] = value;
        }

        process.Start();
        var standardOutputTask = process.StandardOutput.ReadToEndAsync(cancellationToken);
        var standardErrorTask = process.StandardError.ReadToEndAsync(cancellationToken);
        var waitTask = process.WaitForExitAsync(cancellationToken);
        var completed = await Task.WhenAny(waitTask, Task.Delay(timeout, cancellationToken));
        if (completed != waitTask)
        {
            TryKill(process);
            return new ExternalCommandOcrProcessResult(
                ExitCode: -1,
                StandardOutput: string.Empty,
                StandardError: string.Empty,
                TimedOut: true);
        }

        await waitTask;
        return new ExternalCommandOcrProcessResult(
            ExitCode: process.ExitCode,
            StandardOutput: await standardOutputTask,
            StandardError: await standardErrorTask,
            TimedOut: false);
    }

    private static void TryKill(Process process)
    {
        try
        {
            if (!process.HasExited)
            {
                process.Kill(entireProcessTree: true);
            }
        }
        catch (InvalidOperationException)
        {
        }
    }

    private static string QuoteArgument(string value)
    {
        return "\""
            + value
                .Replace("\"", "\\\"", StringComparison.Ordinal)
            + "\"";
    }

    private static IReadOnlyDictionary<string, string> ParseEnvironmentVariables(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return new Dictionary<string, string>();
        }

        var parsed = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var assignment in value.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var equalsIndex = assignment.IndexOf('=', StringComparison.Ordinal);
            if (equalsIndex <= 0)
            {
                continue;
            }

            parsed[assignment[..equalsIndex]] = assignment[(equalsIndex + 1)..];
        }

        return parsed;
    }
}
