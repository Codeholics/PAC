using namespace WinUIShell.Microsoft.UI.Xaml
using namespace WinUIShell.Microsoft.UI.Xaml.Controls

function Show-PacDialog {
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        $Owner
    )

    $dialog = [ContentDialog]::new()
    $dialog.Title = $Title
    $dialog.Content = $Content
    $dialog.CloseButtonText = 'OK'
    $dialog.XamlRoot = $Owner.Content.XamlRoot

    $dialog.ShowAsync() | Out-Null
}

function Show-PacConfirmationDialog {
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        $Owner,

        [string]$PrimaryButtonText = 'OK',

        [string]$CloseButtonText = 'Cancel'
    )

    $dialog = [ContentDialog]::new()
    $dialog.Title = $Title
    $dialog.Content = $Content
    $dialog.PrimaryButtonText = $PrimaryButtonText
    $dialog.CloseButtonText = $CloseButtonText
    $dialog.XamlRoot = $Owner.Content.XamlRoot

    $result = $dialog.ShowAsync().GetAwaiter().GetResult()
    return $result -eq [ContentDialogResult]::Primary
}
