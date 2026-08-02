function Save-PacToolConfig {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,

        [hashtable]$SavedValues,

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

    $savedValues = $SavedValues

    $updatedConfig = [pscustomobject]@{
        defaults = $defaults
        savedValues = $savedValues
    }

    $updatedConfig | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ConfigPath
}