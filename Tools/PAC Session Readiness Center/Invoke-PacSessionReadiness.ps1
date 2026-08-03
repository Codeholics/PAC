param(
    [string]$SqlConnectionString,
    [switch]$RunExchangeTest,
    [switch]$RunSqlTest,
    [switch]$RunLoggingTest
)

function Get-PacSessionModuleCatalog {
    return @(
        [pscustomobject]@{ Name = 'WinUIShell'; RequiredBy = 'PAC Shell' },
        [pscustomobject]@{ Name = 'ActiveDirectory'; RequiredBy = 'AD-aware tools' },
        [pscustomobject]@{ Name = 'ExchangeOnlineManagement'; RequiredBy = 'Exchange-aware tools' },
        [pscustomobject]@{ Name = 'SqlServer'; RequiredBy = 'SQL-aware tools' },
        [pscustomobject]@{ Name = 'ImportExcel'; RequiredBy = 'Excel exports' },
        [pscustomobject]@{ Name = 'PSLogging'; RequiredBy = 'Shared logging' }
    )
}

function Get-PacSessionModuleStatus {
    $moduleStatus = foreach ($module in Get-PacSessionModuleCatalog) {
        [pscustomobject]@{
            Name       = $module.Name
            Available  = [bool](Get-Module -ListAvailable -Name $module.Name)
            Loaded     = [bool](Get-Module -Name $module.Name)
            RequiredBy = $module.RequiredBy
        }
    }

    return @($moduleStatus)
}

function New-PacSessionTestResult {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Message
    )

    return [pscustomobject]@{
        Name      = $Name
        Status    = $Status
        Message   = $Message
        Timestamp = Get-Date
    }
}

function Test-PacExchangeReadiness {
    param(
        [switch]$Requested,

        [Parameter(Mandatory)]
        [System.Collections.IEnumerable]$Modules
    )

    if (-not $Requested) {
        return New-PacSessionTestResult -Name 'Exchange' -Status 'Skipped' -Message 'Exchange session test was not requested.'
    }

    $exchangeModule = @($Modules | Where-Object Name -eq 'ExchangeOnlineManagement' | Select-Object -First 1)
    if (-not $exchangeModule -or -not $exchangeModule[0].Available) {
        return New-PacSessionTestResult -Name 'Exchange' -Status 'Missing' -Message 'ExchangeOnlineManagement is not available.'
    }

    $connectionCommand = Get-Command Get-ConnectionInformation -ErrorAction SilentlyContinue
    if (-not $connectionCommand) {
        return New-PacSessionTestResult -Name 'Exchange' -Status 'ModuleOnly' -Message 'Exchange module is available but no active Exchange session command is loaded.'
    }

    try {
        $connectionInfo = @(Get-ConnectionInformation -ErrorAction Stop)
        if ($connectionInfo.Count -gt 0) {
            return New-PacSessionTestResult -Name 'Exchange' -Status 'Ready' -Message 'An Exchange session appears to be available.'
        }

        return New-PacSessionTestResult -Name 'Exchange' -Status 'Unavailable' -Message 'Exchange module is loaded but no active connection was reported.'
    }
    catch {
        return New-PacSessionTestResult -Name 'Exchange' -Status 'Error' -Message $_.Exception.Message
    }
}

function Test-PacSqlReadiness {
    param(
        [switch]$Requested,

        [string]$ConnectionString,

        [Parameter(Mandatory)]
        [System.Collections.IEnumerable]$Modules
    )

    if (-not $Requested) {
        return New-PacSessionTestResult -Name 'SQL' -Status 'Skipped' -Message 'SQL connection test was not requested.'
    }

    if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
        return New-PacSessionTestResult -Name 'SQL' -Status 'Skipped' -Message 'SQL connection string is blank.'
    }

    $sqlModule = @($Modules | Where-Object Name -eq 'SqlServer' | Select-Object -First 1)
    if (-not $sqlModule -or -not $sqlModule[0].Available) {
        return New-PacSessionTestResult -Name 'SQL' -Status 'Missing' -Message 'SqlServer module is not available.'
    }

    if (-not (Get-Command Invoke-Sqlcmd -ErrorAction SilentlyContinue)) {
        return New-PacSessionTestResult -Name 'SQL' -Status 'Unavailable' -Message 'Invoke-Sqlcmd is not currently available.'
    }

    try {
        $null = Invoke-Sqlcmd -ConnectionString $ConnectionString -Query 'SELECT 1 AS Ready' -ErrorAction Stop
        return New-PacSessionTestResult -Name 'SQL' -Status 'Ready' -Message 'SQL connectivity test succeeded.'
    }
    catch {
        return New-PacSessionTestResult -Name 'SQL' -Status 'Error' -Message $_.Exception.Message
    }
}

function Test-PacLoggingReadiness {
    param(
        [switch]$Requested,

        [Parameter(Mandatory)]
        [System.Collections.IEnumerable]$Modules
    )

    if (-not $Requested) {
        return New-PacSessionTestResult -Name 'Logging' -Status 'Skipped' -Message 'Logging test was not requested.'
    }

    $loggingModule = @($Modules | Where-Object Name -eq 'PSLogging' | Select-Object -First 1)
    if (-not $loggingModule -or -not $loggingModule[0].Available) {
        return New-PacSessionTestResult -Name 'Logging' -Status 'Missing' -Message 'PSLogging is not available.'
    }

    if (-not (Get-Command Write-PSLog -ErrorAction SilentlyContinue)) {
        return New-PacSessionTestResult -Name 'Logging' -Status 'Unavailable' -Message 'Write-PSLog is not currently available.'
    }

    try {
        Write-PSLog -Message ('PAC readiness test at {0}' -f (Get-Date)) -Level Info -ErrorAction Stop
        return New-PacSessionTestResult -Name 'Logging' -Status 'Ready' -Message 'Logging write test succeeded.'
    }
    catch {
        return New-PacSessionTestResult -Name 'Logging' -Status 'Error' -Message $_.Exception.Message
    }
}

function Get-PacToolReadinessStatus {
    param(
        [Parameter(Mandatory)]
        $Capabilities,

        [Parameter(Mandatory)]
        $Authentication,

        [Parameter(Mandatory)]
        [System.Collections.IEnumerable]$Tests
    )

    $exchangeTest = @($Tests | Where-Object Name -eq 'Exchange' | Select-Object -First 1)
    $sqlTest = @($Tests | Where-Object Name -eq 'SQL' | Select-Object -First 1)

    return @(
        [pscustomobject]@{ Tool = 'Compress Directory'; Status = 'Ready'; Reason = 'General filesystem workflow.' },
        [pscustomobject]@{ Tool = 'CSV to JSON'; Status = 'Ready'; Reason = 'General text conversion workflow.' },
        [pscustomobject]@{ Tool = 'Google Maps Url'; Status = 'Ready'; Reason = 'General URL generation workflow.' },
        [pscustomobject]@{ Tool = 'Regex Extractor'; Status = 'Ready'; Reason = 'General text parsing workflow.' },
        [pscustomobject]@{ Tool = 'Text to Speech'; Status = 'Ready'; Reason = 'General desktop speech workflow.' },
        [pscustomobject]@{
            Tool = 'Enterprise User Audit'
            Status = if ($Capabilities.ADToolsReady) {
                if ($Capabilities.ExchangeToolsReady -or $Capabilities.SqlToolsReady) { 'Ready' } else { 'Ready with limitations' }
            } else {
                'Ready with limitations'
            }
            Reason = if ($Authentication.Provider -eq 'AD') {
                if ($exchangeTest -and $exchangeTest[0].Status -eq 'Ready') {
                    'Active Directory is available; deeper Exchange and SQL features depend on current session state.'
                } else {
                    'Active Directory is available; some enrichment features may remain unavailable.'
                }
            } else {
                'Sample-data mode remains available even when enterprise connectivity is unavailable.'
            }
        }
    )
}

function Invoke-PacSessionReadiness {
    [CmdletBinding()]
    param(
        [string]$SqlConnectionString,
        [switch]$RunExchangeTest,
        [switch]$RunSqlTest,
        [switch]$RunLoggingTest
    )

    $authentication = Get-PacAuthenticationProvider
    $networkAvailable = [System.Net.NetworkInformation.NetworkInterface]::GetIsNetworkAvailable()
    $modules = Get-PacSessionModuleStatus
    $adAvailable = Test-PacActiveDirectoryAvailable

    $tests = @(
        (New-PacSessionTestResult -Name 'Active Directory' -Status $(if ($adAvailable) { 'Ready' } else { 'Unavailable' }) -Message $(if ($adAvailable) { 'Domain controller reachability confirmed.' } else { $authentication.Reason })),
        (Test-PacExchangeReadiness -Requested:$RunExchangeTest -Modules $modules),
        (Test-PacSqlReadiness -Requested:$RunSqlTest -ConnectionString $SqlConnectionString -Modules $modules),
        (Test-PacLoggingReadiness -Requested:$RunLoggingTest -Modules $modules)
    )

    $winUiShellStatus = @($modules | Where-Object Name -eq 'WinUIShell' | Select-Object -First 1)
    $importExcelStatus = @($modules | Where-Object Name -eq 'ImportExcel' | Select-Object -First 1)
    $loggingStatus = @($tests | Where-Object Name -eq 'Logging' | Select-Object -First 1)
    $exchangeStatus = @($tests | Where-Object Name -eq 'Exchange' | Select-Object -First 1)
    $sqlStatus = @($tests | Where-Object Name -eq 'SQL' | Select-Object -First 1)

    $capabilities = [pscustomobject]@{
        GeneralToolsReady      = [bool]($winUiShellStatus -and $winUiShellStatus[0].Available)
        ADToolsReady           = $adAvailable
        ExchangeToolsReady     = [bool]($exchangeStatus -and $exchangeStatus[0].Status -eq 'Ready')
        SqlToolsReady          = [bool]($sqlStatus -and $sqlStatus[0].Status -eq 'Ready')
        ExportReady            = [bool]($importExcelStatus -and $importExcelStatus[0].Available)
        LoggingReady           = [bool](($loggingStatus -and $loggingStatus[0].Status -eq 'Ready') -or (@($modules | Where-Object Name -eq 'PSLogging' | Select-Object -First 1)[0].Available))
        EnterpriseWorkflowsReady = $adAvailable
    }

    $runtime = [pscustomobject]@{
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        PSEdition         = $PSVersionTable.PSEdition
        WinUIShellAvailable = [bool]($winUiShellStatus -and $winUiShellStatus[0].Available)
        CurrentUser       = $env:USERNAME
        MachineName       = $env:COMPUTERNAME
        Timestamp         = Get-Date
    }

    $environment = [pscustomobject]@{
        NetworkAvailable        = $networkAvailable
        DomainConnected         = $authentication.DomainJoined
        DomainControllerReachable = $authentication.DomainControllerReachable
    }

    $toolReadiness = Get-PacToolReadinessStatus -Capabilities $capabilities -Authentication $authentication -Tests $tests

    return [pscustomobject]@{
        Runtime       = $runtime
        Authentication = $authentication
        Environment   = $environment
        Modules       = @($modules)
        Tests         = @($tests)
        Capabilities  = $capabilities
        ToolReadiness = @($toolReadiness)
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-PacSessionReadiness @PSBoundParameters
}