function Connect-ExchangeOnlineHelper {
    <#
    .SYNOPSIS
    Simplifies connecting to Exchange Online using the ExchangeOnlineManagement module.

    .DESCRIPTION
    Ensures the `ExchangeOnlineManagement` module is available, then attempts to
    connect. Supports optional credential-based or interactive modern auth.

    .PARAMETER Credential
    Optional PSCredential. If omitted, `Connect-ExchangeOnline` will prompt
    interactively (modern auth) or use cached auth.

    .PARAMETER Organization
    Optional organization parameter passed to `Connect-ExchangeOnline`.

    .PARAMETER RetryCount
    Number of retries on failure (default 1).

    .PARAMETER RetryDelaySeconds
    Seconds to wait between retries (default 5).

    .EXAMPLE
    Connect-ExchangeOnlineHelper -Credential (Get-Credential)

    .EXAMPLE
    Connect-ExchangeOnlineHelper -Organization contoso -RetryCount 2
    #>
    [CmdletBinding()]
    param(
        [System.Management.Automation.PSCredential]$Credential = $null,
        [string]$Organization = $null,
        [int]$RetryCount = 1,
        [int]$RetryDelaySeconds = 5
    )

    begin {
        if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
            try {
                Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -ErrorAction Stop
            } catch {
                Throw "ExchangeOnlineManagement module not available and automatic install failed: $($_.Exception.Message)"
            }
        }

        Import-Module ExchangeOnlineManagement -ErrorAction Stop
    }

    process {
        for ($attempt = 0; $attempt -le $RetryCount; $attempt++) {
            try {
                $params = @{}
                if ($PSBoundParameters.ContainsKey('Credential') -and $Credential) {
                    $params.Credential = $Credential
                }
                if ($Organization) { $params.Organization = $Organization }
                $params.ErrorAction = 'Stop'

                Connect-ExchangeOnline @params

                Write-Verbose 'Connected to Exchange Online.'
                return $true
            } catch {
                if ($attempt -lt $RetryCount) {
                    Start-Sleep -Seconds $RetryDelaySeconds
                    continue
                }

                Throw "Failed to connect to Exchange Online: $($_.Exception.Message)"
            }
        }
    }
}
