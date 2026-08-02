using namespace WinUIShell
using namespace WinUIShell.Microsoft.UI
using namespace WinUIShell.Microsoft.UI.Xaml
using namespace WinUIShell.Microsoft.UI.Xaml.Controls
using namespace WinUIShell.Microsoft.UI.Xaml.Media

function Get-CompressDirectoryPage {
    param(
        [hashtable]$Context
    )

    $toolManifest = Get-PacToolManifest -RootPath $Context.RootPath -ManifestPath 'Tools/Compress Directory/tool.json'
    $inputParameter = $toolManifest.parameters | Where-Object name -eq 'InputDirectory' | Select-Object -First 1
    $outputParameter = $toolManifest.parameters | Where-Object name -eq 'OutputDirectory' | Select-Object -First 1

    return @{
        Name        = $toolManifest.name
        MenuText    = $toolManifest.name
        Category    = $toolManifest.category
        ToolPath    = $toolManifest.toolPath
        ScriptPath  = $toolManifest.scriptPath
        ConfigPath  = $toolManifest.configPath
        InputPath   = $toolManifest.inputPath
        TempPath    = $toolManifest.tempPath
        OutputPath  = $toolManifest.outputPath
        Parameters  = $toolManifest.parameters
        Description = $toolManifest.description

        Icon = @{
            Type       = 'FontIcon'
            Glyph      = [char]0xF012
        }

        # IMPORTANT:
        # WinUIShell does NOT use PageType.
        # Navigation is done by page name.
        # Remove PageType entirely.

        OnLoaded = {
            param($pageName, $page, $e, $pageContext)

            if ($page.Content) { return }

            $panel = [StackPanel]::new()
            $panel.Margin = 32
            $panel.Spacing = 16

            Set-PacPageSurface -Page $page -Panel $panel

            $title = [TextBlock]::new()
            $title.Text = $toolManifest.name
            $title.Style = $pageContext.Resources['TitleTextBlockStyle']

            $text = [TextBlock]::new()
            $text.Text = $toolManifest.description
            $text.Style = $pageContext.Resources['BodyTextBlockStyle']

            $button = [Button]::new()
            $button.Content = 'Open Tool'
            $button.Style = $pageContext.Resources['AccentButtonStyle']

            $openToolCallback = [EventCallback]::new()
            $openToolCallback.ScriptBlock = {
                Show-CompressDirectoryWindow
            }
            $button.AddClick($openToolCallback)

            $panel.Children.Add($title)
            $panel.Children.Add($text)
            $panel.Children.Add($button)

            $page.Content = $panel
        }
    }
}

# =====================================================================
# CHILD WINDOW IMPLEMENTATION
# =====================================================================

function Show-CompressDirectoryWindow {
    $toolManifest = Get-PacToolManifest -RootPath $script:PacRootPath -ManifestPath 'Tools/Compress Directory/tool.json'
    Show-PacSimpleToolWindow -ToolManifest $toolManifest | Out-Null
}
