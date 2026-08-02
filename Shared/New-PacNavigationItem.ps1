using namespace WinUIShell.Microsoft.UI.Xaml.Controls

function New-PacNavigationItem {
    param([hashtable]$PageDefinition)

    $item = [NavigationViewItem]::new()
    $item.Content = $PageDefinition.MenuText
    $item.Tag     = $PageDefinition.Name

    # Icon metadata
    if ($PageDefinition.Icon.Type -eq 'FontIcon') {
        $icon = [FontIcon]::new()
        $icon.Glyph = $PageDefinition.Icon.Glyph
        if (($PageDefinition.Icon.PSObject.Properties.Name -contains 'FontFamily') -and $PageDefinition.Icon.FontFamily) {
            $icon.FontFamily = $PageDefinition.Icon.FontFamily
        }
        $item.Icon = $icon
    } elseif ($PageDefinition.Icon.Type -eq 'SymbolIcon') {
        $symbolValue = $PageDefinition.Icon.Symbol
        $symbolEnum = if ($symbolValue -is [string]) {
            [WinUIShell.Microsoft.UI.Xaml.Controls.Symbol]::$symbolValue
        } else {
            $symbolValue
        }

        if ($symbolValue) {
            $item.Icon = [SymbolIcon]::new($symbolEnum)
        }
    }

    return $item
}
