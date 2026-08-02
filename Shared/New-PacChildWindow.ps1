function New-PacChildWindow {
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [string]$Subtitle = '',

        [int]$Width = 600,

        [int]$Height = 420,

        $OwnerWindow,

        [switch]$CenterOnPointerScreen
    )

    $childWin = [WinUIShell.Microsoft.UI.Xaml.Window]::new()
    $childWin.Title = $Title
    $childWin.AppWindow.TitleBar.PreferredTheme = 'UseDefaultAppMode'
    $childWin.AppWindow.ResizeClient($Width, $Height)

    try {
        $titleBarType = 'WinUIShell.Microsoft.UI.Xaml.Controls.TitleBar' -as [type]
        if ($titleBarType -and ($childWin.PSObject.Methods.Name -contains 'SetTitleBar')) {
            $titleBar = $titleBarType::new()
            $titleBar.Title = $Title
            if (-not [string]::IsNullOrWhiteSpace($Subtitle)) {
                $titleBar.Subtitle = $Subtitle
            }

            $symbolIconSourceType = 'WinUIShell.Microsoft.UI.Xaml.Controls.SymbolIconSource' -as [type]
            $symbolType = 'WinUIShell.Microsoft.UI.Xaml.Controls.Symbol' -as [type]
            if ($symbolIconSourceType -and $symbolType) {
                $iconSource = $symbolIconSourceType::new()
                $iconSource.Symbol = $symbolType::Home
                $titleBar.IconSource = $iconSource
            }

            $childWin | Add-Member -NotePropertyName PacTitleBar -NotePropertyValue $titleBar -Force

            $childWin.SetTitleBar($titleBar)
            $childWin.ExtendsContentIntoTitleBar = $true

            if ($childWin.AppWindow -and $childWin.AppWindow.TitleBar) {
                $childWin.AppWindow.TitleBar.PreferredHeightOption = 'Tall'
            }
        }
    }
    catch {}

    try {
        $backdropTypeNames = @(
            'WinUIShell.Microsoft.UI.Xaml.Media.DesktopAcrylicBackdrop'
            'WinUIShell.Microsoft.UI.Xaml.Media.MicaBackdrop'
            'WinUIShell.Microsoft.UI.DesktopAcrylicBackdrop'
            'WinUIShell.Microsoft.UI.MicaBackdrop'
        )

        foreach ($typeName in $backdropTypeNames) {
            $backdropType = $typeName -as [type]
            if ($backdropType) {
                $childWin.SystemBackdrop = $backdropType::new()
                break
            }
        }
    }
    catch {}

    try {
        $targetScreen = $null

        if ($OwnerWindow -and $global:MainWindowScreen) {
            $targetScreen = $global:MainWindowScreen
        }

        if (-not $targetScreen -and ($CenterOnPointerScreen -or -not $OwnerWindow)) {
            $cursorPos = [System.Windows.Forms.Cursor]::Position
            $targetScreen = [System.Windows.Forms.Screen]::FromPoint($cursorPos)
        }

        if (-not $targetScreen -and $global:MainWindowScreen) {
            $targetScreen = $global:MainWindowScreen
        }

        if (-not $targetScreen) {
            $targetScreen = [System.Windows.Forms.Screen]::PrimaryScreen
        }

        if ($targetScreen) {
            $workingArea = $targetScreen.WorkingArea
            $left = [int]($workingArea.X + (($workingArea.Width - $Width) / 2))
            $top = [int]($workingArea.Y + (($workingArea.Height - $Height) / 2))
            $childWin.AppWindow.Move([Windows.Graphics.PointInt32]::new($left, $top))
        }
    }
    catch {}

    return $childWin
}

function Set-PacChildWindowContent {
    param(
        [Parameter(Mandatory)]
        $Window,

        [Parameter(Mandatory)]
        $Content,

        [switch]$WrapInScrollViewer
    )

    $hostContent = $Content

    if ($WrapInScrollViewer) {
        $scrollViewer = [WinUIShell.Microsoft.UI.Xaml.Controls.ScrollViewer]::new()
        $scrollViewer.VerticalScrollBarVisibility = 'Auto'
        $scrollViewer.HorizontalScrollBarVisibility = 'Disabled'
        $scrollViewer.Content = $Content
        $hostContent = $scrollViewer
    }

    if (($Window.PSObject.Properties.Name -contains 'PacTitleBar') -and $Window.PacTitleBar) {
        $contentGrid = [WinUIShell.Microsoft.UI.Xaml.Controls.Grid]::new()

        $titleBarRow = [WinUIShell.Microsoft.UI.Xaml.Controls.RowDefinition]::new()
        $titleBarRow.Height = [WinUIShell.Microsoft.UI.Xaml.GridLength]::Auto
        $contentRow = [WinUIShell.Microsoft.UI.Xaml.Controls.RowDefinition]::new()
        $contentRow.Height = [WinUIShell.Microsoft.UI.Xaml.GridLength]::new(1, 'Star')

        $contentGrid.RowDefinitions.Add($titleBarRow)
        $contentGrid.RowDefinitions.Add($contentRow)

        [WinUIShell.Microsoft.UI.Xaml.Controls.Grid]::SetRow($Window.PacTitleBar, 0)
        [WinUIShell.Microsoft.UI.Xaml.Controls.Grid]::SetRow($hostContent, 1)

        $contentGrid.Children.Add($Window.PacTitleBar)
        $contentGrid.Children.Add($hostContent)

        $Window.Content = $contentGrid
        return
    }

    $Window.Content = $hostContent
}
