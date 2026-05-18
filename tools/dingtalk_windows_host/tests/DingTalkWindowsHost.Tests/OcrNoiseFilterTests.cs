using DingTalkWindowsHost.Automation.Ocr;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class OcrNoiseFilterTests
{
    [Theory]
    [InlineData("10:42")]
    [InlineData("钉钉")]
    [InlineData("消息")]
    [InlineData("Loading...")]
    [InlineData("加载中...")]
    public void IsForwardable_drops_noise(string text)
    {
        Assert.False(OcrNoiseFilter.IsForwardable(text));
    }

    [Fact]
    public void IsForwardable_accepts_message_like_text()
    {
        Assert.True(OcrNoiseFilter.IsForwardable("报警服务恢复正常"));
    }
}
