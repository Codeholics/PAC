<#
.SYNOPSIS
    Detects the best available authentication provider.

.DESCRIPTION
    Determines whether Active Directory, Entra ID, or Local
    authentication should be used based on the current environment.

.OUTPUTS
    PSCustomObject

.EXAMPLE
    $Auth = Get-AuthenticationProvider

    $Auth.Provider

.EXAMPLE
    switch ((Get-AuthenticationProvider).Provider) {
        'AD'      { 'Use Active Directory' }
        'EntraID' { 'Use Entra ID' }
        'Local'   { 'Use Local Database' }
    }

.NOTES
    Detection Order:
    1. Active Directory
    2. Entra ID (future expansion)
    3. Local
#>
function Get-AuthenticationProvider {

    [CmdletBinding()]
    param()

    $Result = [PSCustomObject]@{
        Provider     = 'Local'
        DomainJoined = $false
        DomainName   = $null
        User         = $env:USERNAME
        Identity     = $env:USERDOMAIN
        Reason       = 'No enterprise authentication detected.'
    }

    try {

        $ComputerSystem = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop

        if ($ComputerSystem.PartOfDomain) {

            $Result.DomainJoined = $true
            $Result.DomainName   = $ComputerSystem.Domain

            try {

                $Domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()

                $null = $Domain.FindDomainController()

                $Result.Provider = 'AD'
                $Result.Reason   = "Domain Controller reachable for domain '$($ComputerSystem.Domain)'."

                return $Result

            }
            catch {

                $Result.Reason = "Computer is domain joined but no Domain Controller is reachable."
            }
        }

        #
        # Future Entra ID Detection
        #
        # Example ideas:
        # - dsregcmd /status
        # - AzureAD joined
        # - Entra token available
        #
        # If detected:
        #
        # $Result.Provider = 'EntraID'
        # return $Result
        #
    }
    catch {

        $Result.Reason = $_.Exception.Message
    }

    return $Result
}