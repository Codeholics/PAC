# PAC Session Readiness Center Plan

## Goal

Add a platform-level PAC tool that validates whether the current machine, session, and user context are ready for PAC enterprise features before a business tool is launched.

This tool should advance PAC itself, not just add another utility.

## Why This Tool Next

PAC already proves two tool lanes:

- simple manifest-driven tools
- a workflow-heavy custom tool through Enterprise User Audit

The next useful step is to strengthen PAC's shared platform behavior:

- module readiness
- network and domain readiness
- Exchange connection readiness
- SQL connection readiness
- logging readiness
- capability state that other PAC tools can reuse

This gives PAC a stronger foundation for future enterprise tools.

## Recommended Name

Preferred name:

- PAC Session Readiness Center

Acceptable alternatives:

- PAC Connection and Access Readiness
- PAC Environment Readiness Center
- PAC Enterprise Readiness Dashboard

## Core Purpose

This tool should answer these questions before a user opens a sensitive PAC tool:

1. Is PAC running with the expected runtime and modules?
2. Is the current machine on-network or off-network?
3. Are AD-dependent features available?
4. Is Exchange connectivity available?
5. Is SQL connectivity available?
6. Is export capability available?
7. Is logging capability available?
8. Which PAC tools are currently usable in this session?

## Recommended Tool Type

Use a custom page or custom child window, not the simple manifest-driven builder.

Reason:

- multiple grouped checks
- live status presentation
- optional connect/test actions
- reusable capability state
- workflow behavior that is broader than a single input-run-result surface

This should be the second major proof case for PAC's complex-tool lane after Enterprise User Audit.

## Existing Functions To Reuse

These existing PAC functions are strong starting points for the readiness model:

- `Get-AuthenticationProvider.ps1`
- `Test-ActiveDirectoryAvailable.ps1`

Recommended usage:

- `Get-AuthenticationProvider` should become a shared PAC platform helper because it returns structured authentication and domain-state information.
- `Test-ActiveDirectoryAvailable` should either remain a low-level AD probe or be folded into the broader readiness model rather than becoming the main platform contract by itself.

Longer-term direction:

- prefer one structured readiness result object over scattered booleans
- allow future tools such as Enterprise User Audit to consume shared capability state instead of independently rechecking environment readiness

## What The UI Should Show

## Section 1: Runtime Status

Show:

- PowerShell version
- WinUIShell availability
- PAC root path
- current user
- machine name
- current date/time
- optional domain identity details when available

## Section 2: Module Readiness

Check and display status for:

- WinUIShell
- ActiveDirectory
- ExchangeOnlineManagement
- SqlServer
- ImportExcel
- PSLogging

Per module, show:

- Available
- Missing
- Loaded
- Required by which PAC tools

## Section 3: Network and Environment Status

Show:

- network available yes/no
- likely domain-connected yes/no
- PAC offline mode summary
- whether AD, Exchange, and SQL workflows should be expected to work

## Section 4: Authentication Provider Status

Show the current authentication direction using shared PAC logic:

- Provider
- DomainJoined
- DomainName
- User
- Identity
- Reason

Expected provider values:

- AD
- EntraID
- Local

This should use `Get-AuthenticationProvider` as the starting contract.

## Section 5: Connection Tests

Actions:

- Test AD query
- Test Exchange connection
- Test SQL connection
- Test export capability
- Test logging write

Each test should return:

- pass/fail
- short summary
- exception text only when needed
- timestamp of last run

## Section 6: PAC Capability Summary

Show a simple capability matrix:

- General Tools Ready
- AD Tools Ready
- Exchange Tools Ready
- SQL Tools Ready
- Export Ready
- Logging Ready
- Enterprise Workflows Ready

This section matters because future PAC tools should be able to consume this state instead of each tool rebuilding the same checks.

## Section 7: Tool Impact Summary

List current PAC tools and their readiness:

- Compress Directory
- CSV to JSON
- Google Maps Url
- Regex Extractor
- Text to Speech
- Enterprise User Audit

Example statuses:

- ready
- ready with limitations
- blocked by missing module
- blocked by offline environment

## Shared Behaviors This Tool Should Prove

This tool should help PAC decide what to promote into shared helpers.

Candidate shared behaviors:

- module detection helper
- reusable status badge rendering
- reusable diagnostic result formatting
- shared capability-state object
- shared session cache
- shared connection-test result model
- tool dependency declaration contract

## Data Contract Direction

This tool should likely introduce a reusable PAC capability object.

Example shape:

```powershell
@{
    Runtime = @{
        PowerShellVersion = ''
        WinUIShellAvailable = $true
        CurrentUser = ''
        MachineName = ''
    }
    Authentication = @{
        Provider = 'Local'
        DomainJoined = $false
        DomainName = $null
        Identity = ''
        Reason = ''
    }
    Modules = @{
        ActiveDirectory = 'Available'
        ExchangeOnlineManagement = 'Missing'
        SqlServer = 'Available'
        ImportExcel = 'Available'
        PSLogging = 'Available'
    }
    Environment = @{
        NetworkAvailable = $true
        DomainConnected = $false
    }
    Capabilities = @{
        GeneralToolsReady = $true
        ADToolsReady = $false
        ExchangeToolsReady = $false
        SqlToolsReady = $true
        ExportReady = $true
        LoggingReady = $true
        EnterpriseWorkflowsReady = $false
    }
}
```

Future PAC tools should be able to read this state rather than re-derive it independently.

## Proposed Folder Layout

```text
PAC/
    Pages/
        Get-PacSessionReadinessPage.ps1
    Tools/
        PAC Session Readiness Center/
            Invoke-PacSessionReadiness.ps1
            tool.json
            config.json
            input/
            temp/
            output/
```

## Script Responsibilities

## Invoke-PacSessionReadiness.ps1

Should:

- detect runtime state
- detect module state
- test network availability
- use `Get-AuthenticationProvider` for provider and domain-state detection
- optionally use `Test-ActiveDirectoryAvailable` as a dedicated AD probe
- optionally test Exchange session availability
- optionally test SQL connection using configured connection string
- optionally test logging
- return one structured result object

## Page Responsibilities

## Get-PacSessionReadinessPage.ps1

Should:

- render grouped readiness sections
- provide buttons for targeted tests
- display current capability summary
- show last test results clearly
- avoid burying important failure reasons in raw text

## Config Direction

Suggested config use:

- default SQL connection string
- optional environment labels
- toggles for which tests are enabled
- saved values for last-used SQL server/database
- optional non-sensitive display preferences

Do not store secrets in config.

## Implementation Order

1. Create the tool folder, manifest, config, and runtime script.
2. Create the PAC page file and register it.
3. Implement module and runtime detection first.
4. Implement `Get-AuthenticationProvider` integration as a shared PAC platform helper.
5. Add network and environment checks.
6. Add Exchange, SQL, and logging tests behind explicit buttons.
7. Return a structured capability object.
8. Decide which helper patterns should move into `Shared\`.

## Validation Plan

Minimum validation:

- tool opens offline without error
- module detection works even with missing enterprise modules
- authentication-provider detection returns a safe local result when no domain controller is reachable
- capability summary renders with partial readiness
- Enterprise User Audit can later consume the same capability model
- no AD, Exchange, or SQL dependency should be required just to open the readiness tool

## Why This Advances PAC

This tool advances PAC because it improves the platform itself:

- better enterprise readiness
- clearer offline behavior
- reusable capability state
- cleaner future tool design
- less duplicated connection logic
- better user trust when enterprise tools are unavailable

## Recommended Follow-Up After This Tool

1. Refactor Enterprise User Audit to consume shared readiness and capability state.
2. Add role-gated remediation actions only after readiness and auth state are reusable.
3. Promote repeated readiness UI and status logic into `Shared\` if a second complex tool needs it.
