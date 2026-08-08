<#!
.SYNOPSIS
    Legacy wrapper for the PAC shared authentication-provider helper.

.DESCRIPTION
    Preserves the historical entry point while delegating to the shared
    PAC-owned helper so there is only one source of truth.
#>

$pacSharedHelper = Join-Path $PSScriptRoot 'Shared\Get-PacAuthenticationProvider.ps1'
if (-not (Get-Command Get-PacAuthenticationProvider -ErrorAction SilentlyContinue)) {
    . $pacSharedHelper
}

function Get-AuthenticationProvider {
    [CmdletBinding()]
    param()

    return Get-PacAuthenticationProvider
}