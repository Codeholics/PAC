param(
    [string]$SqlConnectionString,
    [switch]$RunExchangeTest,
    [switch]$RunSqlTest,
    [switch]$RunLoggingTest
)

$pacRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
if (-not (Get-Command Get-PacAuthenticationProvider -ErrorAction SilentlyContinue)) {
    . (Join-Path $pacRoot 'Shared\Get-PacAuthenticationProvider.ps1')
}

if (-not (Get-Command Test-PacActiveDirectoryAvailable -ErrorAction SilentlyContinue)) {
    . (Join-Path $pacRoot 'Shared\Test-PacActiveDirectoryAvailable.ps1')
}

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

function Test-PacExchangeOnlineReadiness {
    param(
        [switch]$Requested,

        [Parameter(Mandatory)]
        [System.Collections.IEnumerable]$Modules
    )

    if (-not $Requested) {
        return New-PacSessionTestResult -Name 'Exchange Online' -Status 'Skipped' -Message 'Exchange Online session test was not requested.'
    }

    $exchangeModule = @($Modules | Where-Object Name -eq 'ExchangeOnlineManagement' | Select-Object -First 1)
    if (-not $exchangeModule -or -not $exchangeModule[0].Available) {
        return New-PacSessionTestResult -Name 'Exchange Online' -Status 'Missing' -Message 'ExchangeOnlineManagement is not available.'
    }

    $connectionCommand = Get-Command Get-ConnectionInformation -ErrorAction SilentlyContinue
    if (-not $connectionCommand) {
        return New-PacSessionTestResult -Name 'Exchange Online' -Status 'ModuleOnly' -Message 'ExchangeOnlineManagement is available but its connection-inspection command is not loaded in the current session.'
    }

    try {
        $connectionInfo = @(Get-ConnectionInformation -ErrorAction Stop)
        if ($connectionInfo.Count -gt 0) {
            return New-PacSessionTestResult -Name 'Exchange Online' -Status 'Ready' -Message 'An Exchange Online session appears to be available.'
        }

        return New-PacSessionTestResult -Name 'Exchange Online' -Status 'Unavailable' -Message 'ExchangeOnlineManagement is loaded but no active Exchange Online connection was reported.'
    }
    catch {
        return New-PacSessionTestResult -Name 'Exchange Online' -Status 'Error' -Message $_.Exception.Message
    }
}

function Test-PacExchangeOnPremReadiness {
    param(
        [switch]$Requested
    )

    if (-not $Requested) {
        return New-PacSessionTestResult -Name 'Exchange On-Prem' -Status 'Skipped' -Message 'Exchange on-prem session test was not requested.'
    }

    try {
        $exchangeSessions = @(
            Get-PSSession -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.State -eq 'Opened' -and
                    $_.ConfigurationName -and
                    ($_.ConfigurationName -match '^Microsoft\.Exchange')
                }
        )

        if ($exchangeSessions.Count -gt 0) {
            return New-PacSessionTestResult -Name 'Exchange On-Prem' -Status 'Ready' -Message 'An on-prem Exchange remote PowerShell session appears to be available.'
        }

        $exchangeServerCommand = Get-Command Get-ExchangeServer -ErrorAction SilentlyContinue
        if ($exchangeServerCommand) {
            return New-PacSessionTestResult -Name 'Exchange On-Prem' -Status 'Ready' -Message 'On-prem Exchange management commands appear to be loaded in the current session.'
        }

        $exchangeSnapIns = @()
        if (Get-Command Get-PSSnapin -ErrorAction SilentlyContinue) {
            $exchangeSnapIns = @(Get-PSSnapin -ErrorAction SilentlyContinue | Where-Object Name -match '^Microsoft\.Exchange')
        }

        if ($exchangeSnapIns.Count -gt 0) {
            return New-PacSessionTestResult -Name 'Exchange On-Prem' -Status 'Ready' -Message 'On-prem Exchange snap-ins appear to be loaded in the current session.'
        }

        return New-PacSessionTestResult -Name 'Exchange On-Prem' -Status 'Unavailable' -Message 'No on-prem Exchange session or Exchange management shell was detected in the current session.'
    }
    catch {
        return New-PacSessionTestResult -Name 'Exchange On-Prem' -Status 'Error' -Message $_.Exception.Message
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

    $exchangeOnlineTest = @($Tests | Where-Object Name -eq 'Exchange Online' | Select-Object -First 1)
    $exchangeOnPremTest = @($Tests | Where-Object Name -eq 'Exchange On-Prem' | Select-Object -First 1)
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
                if (
                    ($exchangeOnlineTest -and $exchangeOnlineTest[0].Status -eq 'Ready') -or
                    ($exchangeOnPremTest -and $exchangeOnPremTest[0].Status -eq 'Ready')
                ) {
                    'Active Directory is available; Exchange or SQL enrichment can run when the current session is connected.'
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
        (Test-PacExchangeOnlineReadiness -Requested:$RunExchangeTest -Modules $modules),
        (Test-PacExchangeOnPremReadiness -Requested:$RunExchangeTest),
        (Test-PacSqlReadiness -Requested:$RunSqlTest -ConnectionString $SqlConnectionString -Modules $modules),
        (Test-PacLoggingReadiness -Requested:$RunLoggingTest -Modules $modules)
    )

    $winUiShellStatus = @($modules | Where-Object Name -eq 'WinUIShell' | Select-Object -First 1)
    $importExcelStatus = @($modules | Where-Object Name -eq 'ImportExcel' | Select-Object -First 1)
    $loggingStatus = @($tests | Where-Object Name -eq 'Logging' | Select-Object -First 1)
    $exchangeOnlineStatus = @($tests | Where-Object Name -eq 'Exchange Online' | Select-Object -First 1)
    $exchangeOnPremStatus = @($tests | Where-Object Name -eq 'Exchange On-Prem' | Select-Object -First 1)
    $sqlStatus = @($tests | Where-Object Name -eq 'SQL' | Select-Object -First 1)

    $capabilities = [pscustomobject]@{
        GeneralToolsReady      = [bool]($winUiShellStatus -and $winUiShellStatus[0].Available)
        ADToolsReady           = $adAvailable
        ExchangeOnlineToolsReady = [bool]($exchangeOnlineStatus -and $exchangeOnlineStatus[0].Status -eq 'Ready')
        ExchangeOnPremToolsReady = [bool]($exchangeOnPremStatus -and $exchangeOnPremStatus[0].Status -eq 'Ready')
        ExchangeToolsReady     = [bool](
            ($exchangeOnlineStatus -and $exchangeOnlineStatus[0].Status -eq 'Ready') -or
            ($exchangeOnPremStatus -and $exchangeOnPremStatus[0].Status -eq 'Ready')
        )
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