using System.Drawing;
using DingTalkWindowsHost.Automation.Capture;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class ScreenshotBlankDetectorTests
{
    [Fact]
    public void IsMostlyBlank_returns_true_for_black_screenshot()
    {
        using var bitmap = new Bitmap(320, 200);
        using var graphics = Graphics.FromImage(bitmap);
        graphics.Clear(Color.Black);

        Assert.True(ScreenshotBlankDetector.IsMostlyBlank(bitmap));
    }

    [Fact]
    public void IsMostlyBlank_returns_true_for_white_screenshot()
    {
        using var bitmap = new Bitmap(320, 200);
        using var graphics = Graphics.FromImage(bitmap);
        graphics.Clear(Color.White);

        Assert.True(ScreenshotBlankDetector.IsMostlyBlank(bitmap));
    }

    [Fact]
    public void IsMostlyBlank_returns_false_when_chat_like_content_exists()
    {
        using var bitmap = new Bitmap(320, 200);
        using var graphics = Graphics.FromImage(bitmap);
        graphics.Clear(Color.White);
        graphics.FillRectangle(Brushes.LightGray, 24, 24, 180, 40);
        graphics.FillRectangle(Brushes.DodgerBlue, 90, 96, 190, 44);
        graphics.FillRectangle(Brushes.DimGray, 110, 110, 120, 8);

        Assert.False(ScreenshotBlankDetector.IsMostlyBlank(bitmap));
    }
}
