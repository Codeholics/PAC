<div align="center">

# PowerShell Automation Center

PowerShell Automation Center, or PAC, is a WinUI-based PowerShell desktop shell for collecting internal utilities into one clean launcher with shared UI, manifest-driven tools, and room for more complex workflow pages.

![PowerShell 7](https://img.shields.io/badge/PowerShell-7%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)
![WinUI](https://img.shields.io/badge/UI-WinUI%203-0F6CBD?style=for-the-badge&logo=windows11&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Windows-0078D4?style=for-the-badge&logo=windows&logoColor=white)
![Status](https://img.shields.io/badge/Status-Active%20Prototype-2EA043?style=for-the-badge)
![Tools](https://img.shields.io/badge/Tools-7%20Current-8B5CF6?style=for-the-badge)

</div>

## Overview

PAC is intended to be a central PowerShell application for launching reusable admin and utility workflows from a consistent desktop interface. The current implementation focuses on a shared shell, reusable child-window UI, and lightweight manifest-backed tools that can be added without rebuilding the entire application surface.

This repository currently contains a working PAC shell, a growing set of tool pages, and planning documents for authentication, permissions, logging, and broader enterprise workflows.

## Current Tool Set

The app currently exposes these tools from the main navigation:

- Compress Directory
- CSV to JSON
- Enterprise User Audit
- Google Maps Url
- PAC Session Readiness Center
- Regex Extractor
- Text to Speech

These tools live under `Tools/` and are surfaced through page definitions in `Pages/`.

## Highlights

- Shared WinUI shell built with the `WinUIShell` PowerShell module.
- Manifest-driven simple-tool windows for fast tool registration.
- Category-aware navigation model for grouping tools in the left pane.
- Reusable shared helpers for dialogs, child windows, input controls, and page composition.
- Workflow-heavy custom tools for enterprise readiness and audit scenarios alongside the simple-tool builder.
- JSON-first configuration direction for tool settings, metadata, and future user preferences.
- PowerShell-first implementation that keeps individual tools easy to script and maintain.

## Requirements

- Windows
- PowerShell 7 or newer
- `WinUIShell` installed for PowerShell 7

Windows PowerShell 5.1 is not the target runtime for the current PAC UI stack. The startup flow now relaunches in `pwsh` when necessary.

## Quick Start

1. Install PowerShell 7.
2. Install `WinUIShell` for the current user.
3. Launch PAC with the batch file as the default entry point, or run the start script directly from `pwsh` if you prefer.

```powershell
Install-Module WinUIShell -Scope CurrentUser
pwsh -NoProfile -ExecutionPolicy Bypass -File .\start.ps1
```

Primary launcher:

```text
PSExecutionPolicyBypass.bat
```

Direct script launch is also supported and does not require the batch file.

## Project Structure

```text
PAC/
|- Docs/                  Planning and requirements notes
|- Pages/                 Navigation pages and page registration
|- Shared/                Shared PAC UI helpers and tool-window components
|- Tools/                 Individual tools and per-tool manifests/config
|- WinUIShell Samples/    Reference experiments and sample UI scripts
|- modules.json           External module dependency notes
|- PSExecutionPolicyBypass.bat Default launcher
|- start.ps1              Direct PowerShell entry script
```

## Planned Direction

The repo already documents a broader application direction beyond the current utility set. Major planned areas include:

- Active Directory-aware authentication when available.
- Role-based access for sensitive tools.
- User preference persistence with JSON or SQLite.
- Shared logging via `PSLogging`.
- Local module bundling for environments with restricted install rights.
- Registration flows for adding new tools with minimal wiring.

## Authentication Direction

The current planning model distinguishes between local and Active Directory-backed access.

| Auth Type | Authentication | Restricted Group Needed | AD Tools | Exchange Tools | General Tools |
| --- | --- | --- | --- | --- | --- |
| AD | Yes | `SAMPLE SECURITY GROUP` | Yes | Yes | Yes |
| Local | Yes | No | No | No | Yes |

For AD-backed environments, the longer-term goal is to capture key user details, validate group membership, and gate sensitive tooling appropriately.

## Logging Direction

PAC is also intended to support shared logging through `PSLogging` for operational tracing and troubleshooting. The detailed startup and log-writing examples are kept in the planning docs and can be promoted into the runtime once that integration is finalized.

## Dependencies

Current documented external dependencies include:

- `WinUIShell`
- `PSLogging`
- `ActiveDirectory`
- `ExchangeOnlineManagement`
- `SqlServer`
- `ImportExcel`

On-prem Exchange support is currently session-detected rather than module-declared. The readiness workflow can report loaded on-prem Exchange sessions or management shells separately from Exchange Online connectivity.

See `PSModules/modules.json` and the docs in `Docs/` for the current planning notes around packaging and distribution.

## Acknowledgment

Special credit to the creator of WinUIShell, [mdgrs-mei](https://github.com/mdgrs-mei), for building the PowerShell module that makes PAC's WinUI-based shell possible.

WinUIShell repository:

https://github.com/mdgrs-mei/WinUIShell

## Repository Notes

This README reflects the current prototype state of the PAC application. Some features described in the docs are planned architecture rather than completed runtime behavior.

## Roadmap

- Expand the tool catalog beyond the initial conversion and utility set.
- Harden authentication and authorization flows.
- Reuse PAC Session Readiness Center capability state across enterprise workflow tools.
- Add preference persistence and theme handling.
- Improve packaging for restricted enterprise environments.
- Introduce more complex workflow pages alongside manifest-driven tools.
