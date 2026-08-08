function Test-PacActiveDirectoryAvailable {
    try {
        $provider = Get-PacAuthenticationProvider
        return ($provider.Provider -eq 'AD') -and $provider.DomainControllerReachable
    }
    catch {
        return $false
    }
}