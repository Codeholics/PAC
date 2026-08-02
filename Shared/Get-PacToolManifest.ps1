function Get-PacToolManifest {
    param(
        [Parameter(Mandatory)]
        [string]$RootPath,

        [Parameter(Mandatory)]
        [string]$ManifestPath
    )

    $fullManifestPath = if ([System.IO.Path]::IsPathRooted($ManifestPath)) {
        $ManifestPath
    } else {
        Join-Path $RootPath $ManifestPath
    }

    $manifest = Get-Content -LiteralPath $fullManifestPath -Raw | ConvertFrom-Json

    foreach ($propertyName in 'toolPath', 'scriptPath', 'configPath', 'inputPath', 'tempPath', 'outputPath') {
        $property = $manifest.PSObject.Properties[$propertyName]
        if (-not $property) {
            continue
        }

        $property.Value = if ([System.IO.Path]::IsPathRooted($property.Value)) {
            $property.Value
        } else {
            Join-Path $RootPath ($property.Value -replace '/', [string][System.IO.Path]::DirectorySeparatorChar)
        }
    }

    return $manifest
}