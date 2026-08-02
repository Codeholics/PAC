#region Namespaces

using namespace WinUIShell
using namespace WinUIShell.Microsoft.UI
using namespace WinUIShell.Microsoft.UI.Xaml
using namespace WinUIShell.Microsoft.UI.Xaml.Controls
using namespace WinUIShell.Microsoft.UI.Xaml.Media

if ($PSVersionTable.PSEdition -ne 'Core') {
    $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwshCommand) {
        throw 'PAC requires PowerShell 7 (pwsh) because WinUIShell is not supported in Windows PowerShell 5.1. Install PowerShell 7 and relaunch this script.'
    }

    & $pwshCommand.Source -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath @args
    exit $LASTEXITCODE
}

if (-not (Get-Module WinUIShell)) {
    Import-Module WinUIShell
}

if (-not (Get-Module WinUIShell)) {
    throw 'PAC could not load the WinUIShell module in PowerShell 7. Install it for the current user with: Install-Module WinUIShell -Scope CurrentUser'
}

# allow using Screen bounds to center child windows
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
} catch {}

# Load all page modules
$PFunctions = Get-ChildItem (Join-Path -Path $PSScriptRoot -ChildPath "Pages") | Select-object -ExpandProperty FullName | Where-Object { $_ -like '*.ps1'}
foreach ($f in $PFunctions) {
    . $f
}

$sharedFunctions = Get-ChildItem (Join-Path -Path $PSScriptRoot -ChildPath "Shared") | Select-Object -ExpandProperty FullName | Where-Object { $_ -like '*.ps1' }
foreach ($f in $sharedFunctions) {
    . $f
}

#endregion Namespaces

#region Window

$win = [Window]::new()
$win.Title = 'NavigationView + TitleBar'
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
            $win.SystemBackdrop = $backdropType::new()
            break
        }
    }
} catch {}
$win.AppWindow.TitleBar.PreferredTheme = 'UseDefaultAppMode'
$win.AppWindow.ResizeClient(1200, 700)

try {
    $mainWidth = 1200
    $mainHeight = 700
    $cursorPos = [System.Windows.Forms.Cursor]::Position
    $mainScreen = [System.Windows.Forms.Screen]::FromPoint($cursorPos)
    $mainWorking = $mainScreen.WorkingArea
    $mainLeft = [int]($mainWorking.X + (($mainWorking.Width - $mainWidth) / 2))
    $mainTop  = [int]($mainWorking.Y + (($mainWorking.Height - $mainHeight) / 2))
    $win.AppWindow.Move([Windows.Graphics.PointInt32]::new($mainLeft, $mainTop))
    $global:MainWindowScreen = $mainScreen
} catch {}

#endregion Window

#region TitleBar

$autoSuggestBox = [AutoSuggestBox]::new()
$autoSuggestBox.Width = 360
$autoSuggestBox.VerticalAlignment = 'Center'
$autoSuggestBox.PlaceholderText = 'Search..'
$autoSuggestBox.QueryIcon = [SymbolIcon]::new('Find')

$suggestions = [WinUIShell.System.Collections.Generic.List[string]]::new()
$suggestions.Add('Home')
$suggestions.Add('Favorite')
$suggestions.Add('Exchange')
$suggestions.Add('Active Directory')
$suggestions.Add('Reports')

$autoSuggestBox.ItemsSource = $suggestions

$personPicture = [PersonPicture]::new()
$personPicture.Width = 30
$personPicture.Height = 30
$personPicture.Initials = 'ER'

$titleBar = [TitleBar]::new()
try {
    $symbolIconSourceType = 'WinUIShell.Microsoft.UI.Xaml.Controls.SymbolIconSource' -as [type]
    $symbolType = 'WinUIShell.Microsoft.UI.Xaml.Controls.Symbol' -as [type]
    $solidColorBrushType = 'WinUIShell.Microsoft.UI.Xaml.Media.SolidColorBrush' -as [type]
    $colorsType = 'WinUIShell.Microsoft.UI.Colors' -as [type]

    if ($symbolIconSourceType -and $symbolType) {
        $iconSource = $symbolIconSourceType::new()
        $iconSource.Symbol = $symbolType::Emoji2

        if ($solidColorBrushType -and $colorsType) {
            $iconSource.Foreground = $solidColorBrushType::new($colorsType::Aquamarine)
        }

        $titleBar.IconSource = $iconSource
    }
} catch {}

$titleBar.Title = 'PAC'
$titleBar.Subtitle = 'PowerShell Application Center'
$titleBar.Content = $autoSuggestBox
$titleBar.RightHeader = $personPicture

$win.SetTitleBar($titleBar)
$win.ExtendsContentIntoTitleBar = $true
$win.AppWindow.TitleBar.PreferredHeightOption = 'Tall'

#endregion TitleBar

#region NavigationView

$frame = [Frame]::new()

$navigationView = [NavigationView]::new()
$navigationView.Content = $frame
$navigationView.PaneTitle = 'Menu'
$navigationView.ExpandedModeThresholdWidth = 800
$navigationView.CompactModeThresholdWidth = 400

#endregion NavigationView

#region AppContext

$resources = [Application]::Current.Resources
$script:PacRootPath = $PSScriptRoot

$appContext = @{
    RootPath        = $PSScriptRoot
    ToolsRootPath   = Join-Path $PSScriptRoot 'Tools'
    Resources       = $resources
    MainWindow      = $win
    Frame           = $frame
    NavigationView  = $navigationView
}

$appContext.Pages = Register-PacPages -Context $appContext
$pageRegistry = @{}
foreach ($page in $appContext.Pages) {
    $pageRegistry[$page.Name] = $page
}

#endregion AppContext

#region PageBuilder Navigation (WinUIShell)

# This is the correct WinUIShell navigation model.
# DO NOT remove this — your implementation plan depends on it.

$contentPageOnLoaded = {

    param($pageName, $page, $e)

    if ($page.Content) { return }

    $pageDefinition = $pageRegistry[$pageName]
    if ($pageDefinition -and $pageDefinition.OnLoaded) {
        & $pageDefinition.OnLoaded $pageName $page $e $appContext
        return
    }

    $title = [TextBlock]::new()
    $title.Text = "This is $pageName"
    $title.Style = $resources['TitleTextBlockStyle']

    $text = [TextBlock]::new()
    $text.Text = "Welcome to $pageName"
    $text.Style = $resources['BodyTextBlockStyle']

    $button = [Button]::new()
    $button.Content = 'Click Me'
    $button.Style = $resources['AccentButtonStyle']

    $panel = [StackPanel]::new()
    $panel.Margin = 32
    $panel.Spacing = 16

    $page.Background = [SolidColorBrush]::new([Colors]::Transparent)
    $panel.Background = [SolidColorBrush]::new([Colors]::Transparent)

    $panel.Children.Add($title)
    $panel.Children.Add($text)
    $panel.Children.Add($button)

    $page.Content = $panel
}

function Navigate($pageName, $transition) {

    if ($frame.SourcePageName -eq $pageName) {
        return
    }

    $frame.Navigate(
        $pageName,
        $transition,
        [Microsoft.UI.Xaml.Navigation.NavigationCacheMode]::Enabled,
        $contentPageOnLoaded,
        $pageName
    ) | Out-Null
}

#endregion PageBuilder Navigation

#region Menu Items

Write-Host "Pages loaded:" $appContext.Pages.Count
foreach ($page in $appContext.Pages) {
    Write-Host "Page:" $page.Name "Category:" $page.Category
}

# Build menu items from metadata with category grouping
$menuItemMap = @{}
$categoryMap = @{}
$categoryCounts = @{}

foreach ($page in $appContext.Pages) {
    if ([string]::IsNullOrWhiteSpace($page.Category)) {
        continue
    }

    if (-not $categoryCounts.ContainsKey($page.Category)) {
        $categoryCounts[$page.Category] = 0
    }

    $categoryCounts[$page.Category]++
}

foreach ($page in $appContext.Pages) {

    # Create the menu item for the page
    $menuItem = New-PacNavigationItem -PageDefinition $page
    $menuItemMap[$page.Name] = $menuItem

    # Group by category
    $category = $page.Category

    if ([string]::IsNullOrWhiteSpace($category) -or $categoryCounts[$category] -le 1) {
        # No category or only one item in category -> top-level item
        $navigationView.MenuItems.Add($menuItem)
        continue
    }

    # Category exists → ensure parent group exists
    if (-not $categoryMap.ContainsKey($category)) {
        $parent = [NavigationViewItem]::new()
        $parent.Content = $category
        $parent.Icon = [SymbolIcon]::new([WinUIShell.Microsoft.UI.Xaml.Controls.Symbol]::Folder)
        $parent.IsExpanded = $true
        $parent.SelectsOnInvoked = $false

        $categoryMap[$category] = $parent
        $navigationView.MenuItems.Add($parent)
    }

    # Add page as child under its category
    $categoryMap[$category].MenuItems.Add($menuItem)
}

#endregion Menu Items

#region Events

$navigationView.AddItemInvoked({
    param($argumentList, $eventSender, $e)

    if ($e.IsSettingsInvoked) {
        return
    }

    $name = $e.InvokedItemContainer.Tag
    $page = $appContext.Pages | Where-Object Name -eq $name

    if ($page) {
        Navigate $page.Name $e.RecommendedNavigationTransitionInfo
    }
})

$frame.AddNavigated({
    param($argumentList, $eventSender, $e)

    $pageName = $frame.SourcePageName

    $navigationView.IsBackEnabled = $frame.CanGoBack
    $navigationView.Header = $pageName

    if ($menuItemMap.ContainsKey($pageName)) {
        $navigationView.SelectedItem = $menuItemMap[$pageName]
    }
})

#endregion Events

#region Layout

$row0 = [RowDefinition]::new()
$row0.Height = [GridLength]::Auto

$row1 = [RowDefinition]::new()
$row1.Height = [GridLength]::new(1, 'Star')

$grid = [Grid]::new()
$grid.RowDefinitions.Add($row0)
$grid.RowDefinitions.Add($row1)

[Grid]::SetRow($titleBar, 0)
[Grid]::SetRow($navigationView, 1)

$grid.Children.Add($titleBar)
$grid.Children.Add($navigationView)

$win.Content = $grid

#endregion Layout

#region Start

$win.Activate()

Navigate 'Home' $null

$win.WaitForClosed()

#endregion Start