using namespace WinUIShell.Microsoft.UI.Xaml.Controls

function Get-HomePage {
    param(
        [hashtable]$Context
    )

    return @{
        Name     = 'Home'
        MenuText = 'Home'
        Category = $null
        Icon     = @{
            Type = 'SymbolIcon'
            Symbol = 'Home'
        }

        OnLoaded = {
            param($pageName, $page, $e, $pageContext)

            if ($page.Content) {
                return
            }

            $title = [TextBlock]::new()
            $title.Text = 'Home'
            $title.Style = $pageContext.Resources['TitleTextBlockStyle']

            $text = [TextBlock]::new()
            $text.Text = 'Welcome to PAC.'
            $text.Style = $pageContext.Resources['BodyTextBlockStyle']

            $panel = [StackPanel]::new()
            $panel.Margin = 32
            $panel.Spacing = 16

            Set-PacPageSurface -Page $page -Panel $panel

            $panel.Children.Add($title)
            $panel.Children.Add($text)

            $page.Content = $panel
        }
    }
}
