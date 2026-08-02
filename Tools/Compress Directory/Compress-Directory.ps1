param (
    [string]$InputDirectory,
    [string]$OutputDirectory
)

<#!
.SYNOPSIS
Compresses a specified directory into a ZIP file.

.DESCRIPTION
The Compress-Directory function creates a ZIP archive of the specified input directory and saves it to the specified output directory. If the output directory does not exist, it will be created. If a ZIP file with the same name already exists in the output directory, it will be overwritten.

.PARAMETER InputDirectory
The path to the directory you want to compress. This parameter is mandatory.

.PARAMETER OutputDirectory
The path to the directory where the ZIP file will be saved. This parameter is mandatory.

.EXAMPLE
Compress-Directory -InputDirectory "C:\Data\Source" -OutputDirectory "C:\Data\Archives"

This example compresses the "C:\Data\Source" directory into a ZIP file and saves it in "C:\Data\Archives".

.EXAMPLE
$inputs = @{
    InputDirectory = "C:\Users\ereis\Desktop\backup and shipout 2025\Downloads"
    OutputDirectory = "C:\Users\ereis\Desktop\backup and shipout 2025 compressed"
}

Compress-Directory @inputs

.NOTES
Requires .NET Framework and PowerShell 5.0 or later.
The ZIP file will be named after the input directory.
#>
function Compress-Directory {
    param (
        [Parameter(Mandatory = $true)]
        [string]$InputDirectory,

        [Parameter(Mandatory = $true)]
        [string]$OutputDirectory
    )

    # Ensure the input directory exists
    if (-not (Test-Path -LiteralPath $InputDirectory)) {
        throw "Input directory '$InputDirectory' does not exist."
    }

    # Ensure the output directory exists, create it if it doesn't
    if (-not (Test-Path -LiteralPath $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    }

    # Define the output zip file path
    $zipFileName = [System.IO.Path]::GetFileName($InputDirectory) + ".zip"
    $zipFilePath = Join-Path -Path $OutputDirectory -ChildPath $zipFileName

    # Use .NET's ZipFile class to compress the directory
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path -LiteralPath $zipFilePath) {
        Remove-Item -LiteralPath $zipFilePath -Force
    }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($InputDirectory, $zipFilePath)

    Write-Host "Directory '$InputDirectory' has been compressed to '$zipFilePath'."
    return $zipFilePath
}

if ($PSBoundParameters.ContainsKey('InputDirectory') -or $PSBoundParameters.ContainsKey('OutputDirectory')) {
    if (-not $PSBoundParameters.ContainsKey('InputDirectory') -or -not $PSBoundParameters.ContainsKey('OutputDirectory')) {
        throw 'Both InputDirectory and OutputDirectory are required when executing this script directly.'
    }

    Compress-Directory -InputDirectory $InputDirectory -OutputDirectory $OutputDirectory
}

# Compress-Directory -InputDirectory 'D:\test' -OutputDirectory 'D:\'