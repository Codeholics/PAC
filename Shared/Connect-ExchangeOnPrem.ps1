function Connect-ExchangeOnPrem {
    <#
    .SYNOPSIS
    Establishes an implicit remoting session to an on-premises Exchange server.

    .DESCRIPTION
    Uses `New-PSSession` with the `Microsoft.Exchange` configuration to create a
    remote session and optionally imports the session commands into the current
    session via `Import-PSSession`.

    .PARAMETER CASServer
    Short server name (or FQDN) of an Exchange Client Access/CAS server. If
    provided, `ConnectionUri` will be built as "https://<CASServer>/PowerShell/".

    .PARAMETER ConnectionUri
    Full connection URI to the Exchange PowerShell endpoint. Example:
    `https://exch-cas01.contoso.local/PowerShell/`.

    .PARAMETER Credential
    A PSCredential to authenticate with the remote Exchange endpoint. If not
    supplied, `Get-Credential` will be called.

    .PARAMETER Authentication
    Authentication type to use (`Kerberos` or `Basic`). Default is `Kerberos`.

    .PARAMETER ImportSession
    If set, imports the remote Exchange commands into the local session.

    .PARAMETER SessionVariable
    Name of the global variable to store the created PSSession object. Default
    is `ExchangeOnPremSession`.

    .PARAMETER RetryCount
    Number of times to retry the connection on failure (default 1).

    .PARAMETER RetryDelaySeconds
    Delay between retries in seconds (default 5).

    .EXAMPLE
    Connect-ExchangeOnPrem -CASServer exch-cas01 -Credential (Get-Credential) -ImportSession

    .EXAMPLE
    Connect-ExchangeOnPrem -ConnectionUri https://exch.contoso.local/PowerShell/ -Credential $cred

    #>
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$CASServer,

        [Parameter(Position=1)]
        [string]$ConnectionUri,

        [System.Management.Automation.PSCredential]$Credential = (Get-Credential),

        [ValidateSet('Kerberos','Basic')]
        [string]$Authentication = 'Kerberos',

        [switch]$ImportSession,

        [string]$SessionVariable = 'ExchangeOnPremSession',

        [int]$RetryCount = 1,

        [int]$RetryDelaySeconds = 5
    )

    begin {
        if (-not $ConnectionUri) {
            if ($CASServer) {
                $ConnectionUri = "https://$CASServer/PowerShell/"
            } else {
                $domain = $env:USERDNSDOMAIN
                if ($domain) {
                    $ConnectionUri = "https://$domain/PowerShell/"
                }
            }

            if (-not $ConnectionUri) {
                Throw 'Either ConnectionUri or CASServer (or USERDNSDOMAIN) must be supplied.'
            }
        }
    }

    process {
        for ($attempt = 0; $attempt -le $RetryCount; $attempt++) {
            try {
                $opts = @{ ConfigurationName = 'Microsoft.Exchange'; ConnectionUri = $ConnectionUri; Credential = $Credential; Authentication = $Authentication; ErrorAction = 'Stop' }
                # Allow redirection for Basic auth scenarios where CAS may redirect
                $opts.AllowRedirection = $true

                $session = New-PSSession @opts

                if ($ImportSession.IsPresent) {
                    Import-PSSession -Session $session -AllowClobber -DisableNameChecking -ErrorAction Stop
                }

                Set-Variable -Name $SessionVariable -Value $session -Scope Global -Force
                Write-Verbose "Exchange on-prem session created and stored in `$${SessionVariable}."
                return $session
            } catch {
                if ($attempt -lt $RetryCount) {
                    Start-Sleep -Seconds $RetryDelaySeconds
                    continue
                }

                Throw "Failed to create Exchange on-prem session to '$ConnectionUri' : $($_.Exception.Message)"
            }
        }
    }
}
