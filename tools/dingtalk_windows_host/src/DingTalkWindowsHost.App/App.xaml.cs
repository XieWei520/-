namespace DingTalkWindowsHost.App;

public partial class App : System.Windows.Application
{
    internal HostCompositionRoot Services { get; private set; } = null!;

    protected override void OnStartup(System.Windows.StartupEventArgs e)
    {
        base.OnStartup(e);
        Services = HostCompositionRoot.CreateAsync(CancellationToken.None)
            .GetAwaiter()
            .GetResult();

        var window = new MainWindow(Services.CreateMainWindowViewModel());
        MainWindow = window;
        ShutdownMode = System.Windows.ShutdownMode.OnMainWindowClose;
        window.Show();
    }

    protected override void OnExit(System.Windows.ExitEventArgs e)
    {
        if (Services is not null)
        {
            Services.DisposeAsync().AsTask().GetAwaiter().GetResult();
        }

        base.OnExit(e);
    }
}
