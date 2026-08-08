function Save-PacToolConfig {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,

        [hashtable]$SavedValues,

        [bool]$SaveValuesEnabled = $false,

        [string]$InputDirectory,

        [string]$OutputDirectory
    )

    $config = Get-PacToolConfig -ConfigPath $ConfigPath

    $defaults = if ($config.PSObject.Properties['defaults']) {
        $config.defaults
    } else {
        [pscustomobject]@{
            inputDirectory = ''
            outputDirectory = ''
        }
    }

    if (-not $SavedValues) {
        $SavedValues = @{
            inputDirectory = $InputDirectory
            outputDirectory = $OutputDirectory
        }
    }

    $updatedProperties = [ordered]@{}
    foreach ($property in @($config.PSObject.Properties)) {
        if ($property.Name -notin @('defaults', 'savedValues', 'preferences')) {
            $updatedProperties[$property.Name] = $property.Value
        }
    }

    $preferences = [ordered]@{}
    if ($config.PSObject.Properties['preferences'] -and $config.preferences) {
        foreach ($property in @($config.preferences.PSObject.Properties)) {
            if ($property.Name -ne 'SaveValuesEnabled') {
                $preferences[$property.Name] = $property.Value
            }
        }
    }
    $preferences['SaveValuesEnabled'] = [bool]$SaveValuesEnabled

    $updatedProperties['defaults'] = $defaults
    $updatedProperties['preferences'] = $preferences
    $updatedProperties['savedValues'] = if ($SaveValuesEnabled) { $SavedValues } else { @{} }

    $updatedConfig = [pscustomobject]$updatedProperties

    $updatedConfig | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ConfigPath
}