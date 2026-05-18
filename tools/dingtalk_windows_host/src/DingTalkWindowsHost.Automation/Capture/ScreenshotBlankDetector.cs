using System.Drawing;

namespace DingTalkWindowsHost.Automation.Capture;

internal static class ScreenshotBlankDetector
{
    public static bool IsMostlyBlank(Bitmap bitmap)
    {
        ArgumentNullException.ThrowIfNull(bitmap);

        if (bitmap.Width < 1 || bitmap.Height < 1)
        {
            return true;
        }

        var sampleStepX = Math.Max(1, bitmap.Width / 64);
        var sampleStepY = Math.Max(1, bitmap.Height / 64);
        var sampled = 0;
        var lowVariancePixels = 0;
        var totalBrightness = 0d;
        var minBrightness = 255;
        var maxBrightness = 0;

        for (var y = 0; y < bitmap.Height; y += sampleStepY)
        {
            for (var x = 0; x < bitmap.Width; x += sampleStepX)
            {
                var pixel = bitmap.GetPixel(x, y);
                var brightness = (pixel.R + pixel.G + pixel.B) / 3;
                totalBrightness += brightness;
                minBrightness = Math.Min(minBrightness, brightness);
                maxBrightness = Math.Max(maxBrightness, brightness);
                if (brightness <= 8 || brightness >= 247)
                {
                    lowVariancePixels++;
                }

                sampled++;
            }
        }

        if (sampled == 0)
        {
            return true;
        }

        var averageBrightness = totalBrightness / sampled;
        var blankRatio = (double)lowVariancePixels / sampled;
        var brightnessRange = maxBrightness - minBrightness;
        return blankRatio >= 0.985
            && (averageBrightness <= 12 || averageBrightness >= 243)
            && brightnessRange <= 24;
    }
}
