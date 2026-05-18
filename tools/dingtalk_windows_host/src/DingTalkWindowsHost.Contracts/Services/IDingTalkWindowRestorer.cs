using DingTalkWindowsHost.Contracts.Models;

namespace DingTalkWindowsHost.Contracts.Services;

public interface IDingTalkWindowRestorer
{
    DingTalkWindowRestoreResult Restore();
}
