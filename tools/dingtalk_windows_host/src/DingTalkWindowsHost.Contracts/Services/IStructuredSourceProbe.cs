using DingTalkWindowsHost.Contracts.Models;

namespace DingTalkWindowsHost.Contracts.Services;

public interface IStructuredSourceProbe
{
    StructuredSourceProbeResult Probe();
}
