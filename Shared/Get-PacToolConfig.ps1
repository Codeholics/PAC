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