using System;
using System.Drawing;
using System.Windows;
using DingTalkWindowsHost.App.ViewModels;
using WinForms = System.Windows.Forms;

namespace DingTalkWindowsHost.App;

public partial class MainWindow : Window
{
    private readonly WinForms.Panel _hostPanel;
    private readonly MainWindowViewModel _viewModel;

    public MainWindow(MainWindowViewModel viewModel)
    {
        ArgumentNullException.ThrowIfNull(viewModel);

        InitializeComponent();

        _viewModel = viewModel;
        DataContext = _viewModel;

        _hostPanel = new WinForms.Panel
        {
            BackColor = Color.Black,
            Margin = new WinForms.Padding(0),
        };

        HostSurface.Child = _hostPanel;

        Loaded += OnLoaded;
        LocationChanged += OnLocationChanged;
        StateChanged += OnStateChanged;
        Activated += OnActivated;
        SizeChanged += OnSizeChanged;
        Closed += OnClosed;
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        UpdateSurfaceHost();
    }

    private void OnSizeChanged(object sender, SizeChangedEventArgs e)
    {
        UpdateSurfaceHost();
    }

    private void OnLocationChanged(object? sender, EventArgs e)
    {
        UpdateSurfaceHost();
    }

    private void OnStateChanged(object? sender, EventArgs e)
    {
        UpdateSurfaceHost();
    }

    private void OnActivated(object? sender, EventArgs e)
    {
        UpdateSurfaceHost();
    }

    private void OnClosed(object? sender, EventArgs e)
    {
        _viewModel.Dispose();
    }

    private void UpdateSurfaceHost()
    {
        var handle = _hostPanel.Handle;
        var width = _hostPanel.ClientSize.Width;
        var height = _hostPanel.ClientSize.Height;
        _viewModel.UpdateHostSurface(handle, width, height, WindowState == WindowState.Minimized);
    }
}
