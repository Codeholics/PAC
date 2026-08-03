function Get-PacAuthenticationProvider {
    [CmdletBinding()]
    param()

    $result = [pscustomobject]@{
        Provider                 = 'Local'
        DomainJoined             = $false
        DomainName               = $null
        User                     = $env:USERNAME
        Identity                 = $env:USERDOMAIN
        DomainControllerReachable = $false
        Reason                   = 'No enterprise authentication detected.'
    }

    try {
        $computerSystem = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop

        if ($computerSystem.PartOfDomain) {
            $result.DomainJoined = $true
            $result.DomainName = $computerSystem.Domain

            try {
                $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
                $null = $domain.FindDomainController()

                $result.Provider = 'AD'
                $result.DomainControllerReachable = $true
                $result.Reason = "Domain controller reachable for domain '$($computerSystem.Domain)'."

                return $result
            }
            catch {
                $result.Reason = 'Computer is domain joined but no domain controller is reachable.'
            }
        }
    }
    catch {
        $result.Reason = $_.Exception.Message
    }

    return $result
}