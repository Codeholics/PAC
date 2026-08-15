# Path to the Functions directory
$moduleParentPath = (Split-Path -Parent $PSScriptRoot)
$functionPath = (Join-Path -Path $moduleParentPath -ChildPath 'Shared')
Get-ChildItem -Path $functionPath -Filter '*.ps1' -File | ForEach-Object {
    . $_.FullName
}

Export-ModuleMember -Function `
    Connect-ExchangeOnlineHelper, `
    Connect-ExchangeOnPrem, `
    Get-PacAuthenticationProvider, `
    Test-PacActiveDirectoryAvailable, `
    Get-PacToolConfig, `
    Test-PacToolConfigSaveValuesEnabled, `
    Get-PacToolManifest, `
    New-PacChildWindow, `
    Set-PacChildWindowContent, `
    New-PacNavigationItem, `
    Resolve-PacPickerDirectory, `
    New-PacToolTextInput, `
    Save-PacToolConfig, `
    Set-PacPageSurface, `
    Show-PacDialog, `
    Show-PacConfirmationDialog, `
    Test-PacToolValuePresent, `
    Get-PacToolConfigValue, `
    Test-PacToolConfigHasEntry, `
    ConvertFrom-PacNumberInput, `
    Test-PacControlHasTextProperty, `
    Test-PacControlIsComboBox, `
    Test-PacAllowedValue, `
    Get-PacValidationMessage, `
    Get-PacCustomText, `
    Get-PacToolDialogText, `
    Resolve-PacActionDirectory, `
    Get-PacActionOutputPath, `
    Resolve-PacOpenResultTarget, `
    Resolve-PacOutputActionTarget, `
    Test-PacActionHasTarget, `
    Reset-PacRunSurfaceState, `
    Get-PacSavedOutputSummary, `
    Get-PacSkippedOutputSummary, `
    Test-PacNetworkAvailability