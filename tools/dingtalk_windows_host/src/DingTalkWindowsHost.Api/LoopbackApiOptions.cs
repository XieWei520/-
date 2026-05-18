namespace DingTalkWindowsHost.Api;

public sealed record LoopbackApiOptions(string LocalToken)
{
    public const string TokenHeaderName = "X-DingTalk-Host-Token";

    public static LoopbackApiOptions CreateDefault()
    {
        var token = Environment.GetEnvironmentVariable("DINGTALK_HOST_TOKEN");
        return new LoopbackApiOptions(string.IsNullOrWhiteSpace(token) ? "local-dev-token" : token);
    }
}
