using DingTalkWindowsHost.Contracts.Models;

namespace DingTalkWindowsHost.Contracts.Services;

public interface IDingTalkMessageNavigator
{
    DingTalkNavigationResult OpenMessages(IntPtr windowHandle);

    DingTalkNavigationResult CloseSearchOverlay(IntPtr windowHandle);
}
