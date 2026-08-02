using namespace WinUIShell.Microsoft.UI
using namespace WinUIShell.Microsoft.UI.Xaml.Media

function Set-PacPageSurface {
    param(
        [Parameter(Mandatory)]
        $Page,

        [Parameter(Mandatory)]
        $Panel
    )

    $transparentBrush = [SolidColorBrush]::new([Colors]::Transparent)
    $Page.Background = $transparentBrush
    $Panel.Background = $transparentBrush
}