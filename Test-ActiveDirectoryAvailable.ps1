$pacSharedHelper = Join-Path $PSScriptRoot 'Shared\Test-PacActiveDirectoryAvailable.ps1'
if (-not (Get-Command Test-PacActiveDirectoryAvailable -ErrorAction SilentlyContinue)) {
    . $pacSharedHelper
}

function Test-ActiveDirectoryAvailable {
    return Test-PacActiveDirectoryAvailable
}