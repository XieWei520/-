using DingTalkWindowsHost.Automation.Capture;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class UiaExceptionClassifierTests
{
    [Fact]
    public void IsTransient_treats_element_not_available_by_type_name_as_recoverable()
    {
        Assert.True(UiaExceptionClassifier.IsTransient(new ElementNotAvailableException()));
    }

    private sealed class ElementNotAvailableException : Exception
    {
    }
}
