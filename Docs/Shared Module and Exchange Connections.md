# Shared Module and Exchange Connections

## Purpose

PAC shared helpers are maintained as individual scripts in `Shared/` and can be loaded together through the local PAC module at `PSModules/PAC.psm1`.

The PAC module exports the public helper functions used by the shell, pages, and tools. Individual files in `Shared/` should define functions only; do not call `Export-ModuleMember` from those files. `Export-ModuleMember` belongs in `PAC.psm1`.

## Importing the Local Module

From the PAC repository root, import the module by its explicit path:

```powershell
Import-Module .\PSModules\PAC.psm1 -Force
```

Verify that the module loaded and that functions are available:

```powershell
Get-Module -Name PAC
Get-Command -Module PAC | Sort-Object Name
```

PAC startup should import this local module before page scripts are loaded, because pages and tool scripts can call shared functions during setup.

Use a path import for the repository-local module. `Import-Module PAC` works only after the module is installed in a folder on `$env:PSModulePath` using PowerShell's normal module-folder layout.

## Adding a Shared Function

1. Create a `Shared/<Verb>-Pac<Feature>.ps1` script that defines one or more functions.
2. Add the public function name to `Export-ModuleMember` in `PSModules/PAC.psm1`.
3. Import the module with `-Force` during development.
4. Verify the exported command with `Get-Command -Module PAC`.

Use names that avoid collisions with commands provided by external modules. Internal PAC wrappers may use a PAC-specific name or suffix when a direct name would hide an external cmdlet.

## Exchange Connections

Exchange Online and on-premises Exchange are independent connection types. PAC must not treat one as a prerequisite for the other.

| Connection | PAC helper | Underlying mechanism | Connection state |
| --- | --- | --- | --- |
| Exchange Online | `Connect-ExchangeOnlineHelper` | `ExchangeOnlineManagement` and `Connect-ExchangeOnline` | Managed by the ExchangeOnlineManagement module |
| Exchange On-Premises | `Connect-ExchangeOnPrem` | `New-PSSession` using `Microsoft.Exchange` | Stored as a PSSession, by default in `$global:ExchangeOnPremSession` |

### Exchange Online

Use this when a workflow requires Microsoft 365 / Exchange Online commands:

```powershell
Connect-ExchangeOnlineHelper
```

The helper imports `ExchangeOnlineManagement`, installs it for the current user only when it is unavailable, and uses the module's normal interactive authentication when no credential is supplied.

For an explicit credential or organization:

```powershell
$credential = Get-Credential
Connect-ExchangeOnlineHelper -Credential $credential -Organization contoso
```

### Exchange On-Premises

Use this when a workflow requires a remote Exchange PowerShell endpoint:

```powershell
Connect-ExchangeOnPrem -CASServer exch-cas01 -Credential (Get-Credential)
```

To import the remote Exchange commands into the current PowerShell session:

```powershell
Connect-ExchangeOnPrem -CASServer exch-cas01 -Credential (Get-Credential) -ImportSession
```

The helper builds `https://<CASServer>/PowerShell/` when `-CASServer` is supplied. Supply `-ConnectionUri` when the endpoint uses a different URL. The default authentication mechanism is Kerberos; Basic is available only when required by the Exchange endpoint.

## Hybrid Environments

In a hybrid environment, connect only to the service required by the active workflow:

```powershell
# Cloud-only workflow
Connect-ExchangeOnlineHelper

# On-premises-only workflow
Connect-ExchangeOnPrem -CASServer exch-cas01

# Hybrid workflow that genuinely requires both
Connect-ExchangeOnlineHelper
Connect-ExchangeOnPrem -CASServer exch-cas01
```

The PAC Session Readiness Center evaluates Exchange Online and Exchange On-Premises separately, then sets `ExchangeToolsReady` to true when either connection is ready. A failed or missing on-premises session does not invalidate a working Exchange Online connection, and vice versa.

## Troubleshooting

If the PAC module does not expose an expected helper:

```powershell
Import-Module .\PSModules\PAC.psm1 -Force -Verbose
Get-Command -Module PAC
```

Check that the function is defined in `Shared/`, dot-sourced by `PAC.psm1`, and included in its `Export-ModuleMember` list. Do not add `Export-ModuleMember` to an individual `.ps1` helper: it fails outside module scope.
