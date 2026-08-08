function Get-PacToolConfig {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        return [pscustomobject]@{}
    }

    $rawConfig = Get-Content -LiteralPath $ConfigPath -Raw
    if ([string]::IsNullOrWhiteSpace($rawConfig)) {
        return [pscustomobject]@{}
    }

    return $rawConfig | ConvertFrom-Json
}

function Test-PacToolConfigSaveValuesEnabled {
    param(
        [AllowNull()]
        $Config
    )

    if ($null -eq $Config) {
        return $false
    }

    if ($Config.PSObject.Properties.Name -notcontains 'preferences') {
        return $false
    }

    $preferences = $Config.preferences
    if ($null -eq $preferences -or ($preferences.PSObject.Properties.Name -notcontains 'SaveValuesEnabled')) {
        return $false
    }

    return [bool]$preferences.SaveValuesEnabled
}