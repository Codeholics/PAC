function Test-ActiveDirectoryAvailable {

    try {
        $computer = Get-CimInstance Win32_ComputerSystem

        if (-not $computer.PartOfDomain) {
            return $false
        }

        $null = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().FindDomainController()

        return $true
    }
    catch {
        return $false
    }
}