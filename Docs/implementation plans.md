# PAC Modular Implementation Plan

- [PAC Modular Implementation Plan](#pac-modular-implementation-plan)
  - [Goal](#goal)
    - [Current Next Step](#current-next-step)
  - [Preferred Tool Organization](#preferred-tool-organization)
  - [Current Problem](#current-problem)
  - [Recommended Architecture](#recommended-architecture)
    - [1. Application Shell](#1-application-shell)
    - [2. Page Registry](#2-page-registry)
    - [3. Page Modules](#3-page-modules)
    - [4. Shared UI Helpers](#4-shared-ui-helpers)
  - [Suggested Folder Layout](#suggested-folder-layout)
  - [Recommended Tool Folder Contract](#recommended-tool-folder-contract)
  - [Recommended Page Contract](#recommended-page-contract)
  - [Recommended Context Object](#recommended-context-object)
  - [Current Status Snapshot](#current-status-snapshot)
  - [Refactor Strategy For Your Current Script](#refactor-strategy-for-your-current-script)
    - [✅ Phase 1: Separate the current Compress Directory UI](#-phase-1-separate-the-current-compress-directory-ui)
    - [✅ Phase 2: Move menu item creation into metadata](#-phase-2-move-menu-item-creation-into-metadata)
    - [🚧 Phase 3: Introduce shared child-window and dialog helpers](#-phase-3-introduce-shared-child-window-and-dialog-helpers)
    - [✅ Phase 3A: Restore PAC Visual Consistency](#-phase-3a-restore-pac-visual-consistency)
    - [⏳ Phase 4: Add data-driven tools for common script shapes](#-phase-4-add-data-driven-tools-for-common-script-shapes)
  - [Minimal Change Design For Right Now](#minimal-change-design-for-right-now)
  - [Better Final Design](#better-final-design)
  - [Practical Example Of The First Refactor](#practical-example-of-the-first-refactor)
    - [✅ Step A: start.ps1 responsibilities](#-step-a-startps1-responsibilities)
    - [🚧 Step B: Compress page responsibilities](#-step-b-compress-page-responsibilities)
    - [🚧 Step C: Shared helper responsibilities](#-step-c-shared-helper-responsibilities)
  - [Naming Recommendations](#naming-recommendations)
  - [Accuracy Check](#accuracy-check)
  - [Risks To Avoid](#risks-to-avoid)
    - [1. Do not let page files depend on hidden globals](#1-do-not-let-page-files-depend-on-hidden-globals)
    - [2. Do not mix tool registration with UI building logic everywhere](#2-do-not-mix-tool-registration-with-ui-building-logic-everywhere)
    - [3. Do not over-engineer metadata too early](#3-do-not-over-engineer-metadata-too-early)
    - [4. Do not assume helper type resolution will come from the caller](#4-do-not-assume-helper-type-resolution-will-come-from-the-caller)
  - [Recommended Next Implementation Order](#recommended-next-implementation-order)
  - [Bottom Line](#bottom-line)

## Goal

Status legend:

- ✅ complete
- ❌ no longer valid / replaced
- 🚧 working on
- ⏳ pending future step

Make `start.ps1` the application shell only, and move tool-specific UI and execution logic into separate page modules. The enhancement path for a new script should become:

1. Add the tool directory and script or function file.
2. Add one page module file.
3. Register the page in one central registry.
4. Avoid editing the main navigation or page-building logic in multiple places.

## Current Next Step

If you only need one answer from this document, use this section instead of scanning older completed phases.

The current next implementation step is:

- ⏳ when the first workflow-heavy tool arrives, implement it as a custom page or custom child window that reuses PAC shared helpers to validate the two-lane architecture

The most concrete follow-up inside that step is:

- pick the first tool whose workflow genuinely does not fit the manifest-driven builder cleanly, and keep it on a custom page or custom child-window path while reusing shared PAC helpers where they still fit

The next concrete slice inside that step should be:

- use that first workflow-heavy tool to prove the boundary between simple self-building tools and custom tool windows, while reusing the shared child-window chrome and other helper surfaces where appropriate

How to read the roadmap correctly:

- the authoritative next step is the first item in `Recommended Next Implementation Order` that is not marked `✅`
- items marked `✅` are already complete and are not next steps
- older phase descriptions explain history and rationale, not necessarily the current next action

Safest architecture rule for future tools:

- PAC does not need one UI pattern for every tool.
- simple tools should use the shared manifest-driven builder when they fit the contract.
- builder capabilities such as `allowedValues`, numeric constraints, and result actions are optional features, not mandatory requirements for every tool.
- complex or workflow-heavy tools should keep a custom page or custom child window while still reusing shared PAC helpers.
- adding an optional builder capability does not lock all future tools into using it.

## Preferred Tool Organization

Keep each tool inside its own directory under `Tools\`.

Example:

- `Tools\Compress Directory\Compress-Directory.ps1`
- `Tools\Compress Directory\tool.json`
- `Tools\Compress Directory\config.json`
- `Tools\Compress Directory\input\`
- `Tools\Compress Directory\temp\`
- `Tools\Compress Directory\output\`

This is a better fit for PAC than a shared `Scripts\` folder because each tool can keep its own:

- execution script
- page-specific metadata
- config files
- input files or staging files
- temp working files
- exported files or reports
- helper files that only belong to that tool

That will make long-term maintenance much cleaner as the number of tools grows.

For PAC, requiring `tool.json` from the first tool is the right tradeoff. It gives every tool the same registration contract immediately, avoids a one-off special case for the first tool, and makes later automation simpler.

## Current Problem

The remaining problem areas are now narrower than when this plan started.

Right now PAC still has a few responsibilities and decisions that need to be tightened:

- window setup
- title bar setup
- navigation setup
- menu item creation
- generic page creation
- child-window chrome standardization
- manifest-backed tool metadata
- repeated form-building patterns that will matter as more tools are added

The current implementation is workable for one tool, but it will become difficult once you add:

- more scripts with different parameters
- file and folder pickers
- spreadsheet output options
- authentication/role-based behavior
- shared validation and dialog handling

## Recommended Architecture

Split the app into four areas:

### 1. Application Shell

Keep these in `start.ps1`:

- namespace imports
- module imports
- root app context creation
- main window creation
- title bar creation
- navigation events
- frame navigation
- startup logic

`start.ps1` should not know how any individual tool window is built.

PAC should support two tool-window lanes over time:

- a self-building manifest-driven path for simple tools
- a custom page/window path for complex tools that need richer workflow behavior

### 2. Page Registry

Create one registry file that returns the list of pages.

Suggested file:

- `Pages\Register-PacPages.ps1`

This registry should return a collection of page definitions. Each page definition should describe:

- page name
- menu text
- category
- icon
- page load handler
- optional child window launcher
- optional visibility rule

### 3. Page Modules

Create one page module per tool.

Suggested folder:

- `Pages\`

Suggested files:

- `Pages\Get-HomePage.ps1`
- `Pages\Get-CompressDirectoryPage.ps1`
- `Pages\Get-GoogleMapsUrlPage.ps1`
- `Pages\Get-TextToSpeechPage.ps1`
- `Pages\Get-ReportsPage.ps1`
- `Pages\Get-ExchangePage.ps1`

Each file should export a single function that returns a page definition hashtable.

### 4. Shared UI Helpers

Create shared helper files for repeated UI logic.

Suggested folder:

- `Shared\`

Suggested files:

- `Shared\New-PacChildWindow.ps1`
- `Shared\Show-PacDialog.ps1`
- `Shared\Get-PacWorkingArea.ps1`
- `Shared\New-PacLabeledTextBox.ps1`
- `Shared\Show-PacSimpleToolWindow.ps1`
- `Shared\Invoke-PacScriptAction.ps1`

This will remove repeated dialog setup and child window setup from every page.

Those shared helpers should be reused by both lanes so even complex tools are still assembled from common PAC primitives instead of becoming isolated one-off implementations.

## Suggested Folder Layout

```text
PAC/
    start.ps1
    modules.json
    Pages/
        Register-PacPages.ps1
        Get-HomePage.ps1
        Get-CompressDirectoryPage.ps1
        Get-ReportsPage.ps1
    Shared/
        New-PacChildWindow.ps1
        Show-PacDialog.ps1
        Get-PacWorkingArea.ps1
        New-PacLabeledTextBox.ps1
        Invoke-PacScriptAction.ps1
    Tools/
        Compress Directory/
            Compress-Directory.ps1
            tool.json
            config.json
            input/
            temp/
            output/
```

## Recommended Tool Folder Contract

Each tool directory should be self-contained.

Suggested contents:

- main script file
- required tool metadata file
- optional tool config file
- input directory
- temp directory
- output directory
- optional helper files local to the tool

Example:

```text
Tools/
    Compress Directory/
        Compress-Directory.ps1
        tool.json
        config.json
        input/
        temp/
        output/
```

Suggested responsibilities:

- `Compress-Directory.ps1`: the execution logic
- `tool.json`: required tool manifest for display name, category, parameters, output type, and owned paths
- `config.json`: defaults, environment-specific settings, saved paths
- `input\`: source files, staged imports, or tool-owned working inputs
- `temp\`: working files created during execution
- `output\`: generated exports, reports, spreadsheets

The page module should call into the tool folder, not hold the execution logic itself.

For PAC specifically, `input\` is useful when a tool needs a predictable place for incoming files, seed data, or sample payloads that should live with the tool rather than in a shared app folder.

`tool.json` should be treated as the source of truth for tool registration, even when there is only one tool.

## Recommended Page Contract

Each page module should return a hashtable with a stable shape.

Example:

```powershell
function Get-CompressDirectoryPage {
    param(
        [hashtable]$Context
    )

    return @{
        Name = 'Compress Directory'
        MenuText = 'Compress Directory'
        Category = 'Conversion'
        Icon = @{
            Type = 'FontIcon'
            Glyph = [char]0xF012
        }
        OnLoaded = {
            param($pageName, $page, $e, $pageContext)

            if ($page.Content) {
                return
            }

            $panel = [StackPanel]::new()
            $panel.Margin = 32
            $panel.Spacing = 16

            $title = [TextBlock]::new()
            $title.Text = 'Compress Directory'
            $title.Style = $pageContext.Resources['TitleTextBlockStyle']

            $text = [TextBlock]::new()
            $text.Text = 'Open the tool window and provide input/output paths.'
            $text.Style = $pageContext.Resources['BodyTextBlockStyle']

            $button = [Button]::new()
            $button.Content = 'Open Tool'
            $button.Style = $pageContext.Resources['AccentButtonStyle']

            $page.Background = [SolidColorBrush]::new([Colors]::Transparent)
            $panel.Background = [SolidColorBrush]::new([Colors]::Transparent)

            $openToolCallback = [EventCallback]::new()
            $openToolCallback.ScriptBlock = {
                Show-CompressDirectoryWindow
            }
            $button.AddClick($openToolCallback)

            $panel.Children.Add($title)
            $panel.Children.Add($text)
            $panel.Children.Add($button)
            $page.Content = $panel
        }
    }
}
```

The important part is that the page does not depend on loose outer variables. It should get everything it needs through `$Context`.

## Recommended Context Object

Build one application context in `start.ps1` and pass it everywhere.

Example:

```powershell
$appContext = @{
    RootPath = $PSScriptRoot
    ToolsRootPath = Join-Path -Path $PSScriptRoot -ChildPath 'Tools'
    Resources = $resources
    MainWindow = $win
    Frame = $frame
    NavigationView = $navigationView
}
```

Later, this can also hold:

- config values
- authentication state
- current user record
- logging path
- imported modules
- feature flags

## Current Status Snapshot

The current PAC shell is partway through the modular refactor.

What is already working in code:

- `start.ps1` now builds the shell, creates `$appContext`, loads page modules, and builds navigation from registered page metadata.
- `Pages\Register-PacPages.ps1` is now the registry entry point for pages.
- `Pages\Get-HomePage.ps1`, `Pages\Get-CompressDirectoryPage.ps1`, `Pages\Get-GoogleMapsUrlPage.ps1`, `Pages\Get-CSVToJSONPage.ps1`, `Pages\Get-RegexExtractorPage.ps1`, and `Pages\Get-TextToSpeechPage.ps1` exist and are being used by navigation.
- `Shared\New-PacNavigationItem.ps1`, `Shared\Show-PacDialog.ps1`, `Shared\New-PacChildWindow.ps1`, `Shared\Set-PacPageSurface.ps1`, `Shared\Get-PacToolManifest.ps1`, `Shared\Get-PacToolConfig.ps1`, `Shared\Save-PacToolConfig.ps1`, `Shared\New-PacToolTextInput.ps1`, and `Shared\Show-PacSimpleToolWindow.ps1` now exist.
- `Tools\Compress Directory\Compress-Directory.ps1` can now be executed directly with `-InputDirectory` and `-OutputDirectory`.
- `Tools\Google Maps Url\Get-GoogleMapsURL.ps1` can now be executed directly with `-Address` and is no longer dependent on a live web request just to generate a URL.
- `Tools\Text to Speech\Invoke-Speech.ps1` can now be executed directly with PAC-style script parameters instead of only working as a loaded function definition.
- the main PAC window is centered on the screen where the mouse pointer is located when the app starts.
- the Compress Directory child window now opens through the shared manifest-driven helper and is centered using PAC window rules.
- page-specific loaders now apply transparent page surfaces so they visually match the shell.
- the Compress Directory UI now reads default or saved input and output paths from `config.json`.
- the Compress Directory tool now uses the shared manifest-driven simple-tool window builder as a fifth real proof case.
- the Google Maps Url tool now proves the same modular pattern works for a second tool with a different parameter shape and follow-up actions.
- the Google Maps Url tool now uses a shared manifest-driven simple-tool window builder for parameters, result display, and common follow-up actions.
- the Text to Speech tool now uses the shared manifest-driven simple-tool window builder as a second real proof case.
- the CSV to JSON tool now uses the shared manifest-driven simple-tool window builder as a third real proof case.
- the Regex Extractor tool now uses the shared manifest-driven simple-tool window builder as a fourth real proof case.
- the shared simple-tool input helper now supports multiline text areas and boolean checkbox inputs driven by manifest metadata.
- the shared simple-tool input helper now supports dropdown rendering for `allowedValues`, first-class file and folder pickers, richer picker metadata such as initial directories and save/open picker modes, and optional file-import buttons for text inputs.
- the shared simple-tool window builder now supports successful no-result runs, boolean parameter passing, omission of blank optional parameters, numeric parameter validation/conversion before script invocation, manifest-driven `min`, `max`, and `allowedValues` validation, manifest-defined result formatting modes, builder-owned pre-run output-file parameters that can persist returned text results, explicit overwrite and parent-directory policies for those output files, extension-aware save-path normalization, load-time normalized display for saved output paths, optional overwrite-confirmation flows, reusable open-output follow-up actions for those saved files, saved-output run-state messaging in both the result surface and success dialog, skipped-output messaging for canceled or non-written output files, runtime picker-backed file and folder validation with manifest overrides, custom validation message overrides from tool manifests, action-specific dialog title/message overrides, tool-level runtime dialog title/message overrides, and reusable `saveResult` and `openContainingFolder` result actions.
- the Text to Speech tool exposed that blank string config values must not be converted directly into booleans when a tool window opens.
- the shared builder now preserves valid `0` values from config instead of dropping them through truthiness checks.
- the shared builder now reads both exact parameter names and older camelCase config keys so legacy tool configs can survive the move onto the self-building path.
- PAC runtime validation now confirms Text to Speech accepts valid numeric inputs and rejects invalid numeric inputs such as `Volume = 101` with a popup instead of failing silently.
- the Text to Speech manifest now encodes the actual speech-engine bounds for `Speed` (`-10..10`) and `Volume` (`0..100`) instead of leaving those limits implicit in the script runtime.
- the Text to Speech manifest is now the first real proof case for manifest-defined custom validation messages overriding the builder's generic popup text.
- the Google Maps Url manifest is now the first real proof case for manifest-defined action dialog titles and messages overriding the builder's generic copy/open action popups.
- the Compress Directory manifest is now the first real proof case for tool-level runtime dialog overrides such as custom missing-input and error titles.
- the CSV to JSON and Compress Directory manifests now prove picker metadata can choose tool-owned starting directories for import and folder-browse actions.
- the Text to Speech manifest is now the first real proof case for tool-level run success and no-result dialog overrides.
- the CSV to JSON manifest is now the first real proof case for the reusable `saveResult` action.
- the Compress Directory manifest is now the first real proof case for the reusable `openContainingFolder` action.
- the CSV to JSON and Regex Extractor manifests are now the first proof cases for manifest-defined pretty-JSON result rendering in the shared result surface.
- the CSV to JSON and Regex Extractor manifests are now also the first proof cases for builder-owned pre-run output-file parameters that save formatted JSON during the run instead of only through a post-run action.
- the CSV to JSON and Regex Extractor manifests are now also the first proof cases for reusable open-output follow-up actions that target the saved file path chosen before the run.
- runs that save output through builder-owned output-file parameters now surface the written path directly in the result area and success dialog, with optional template tokens for saved-output count and paths.
- the Compress Directory manifest is now the first proof case for explicit picker-backed folder validation rules and custom folder-path validation messages.
- the reusable `saveResult` action path in the shared builder now goes through the same save helper as builder-owned output-file parameters, so extension normalization, overwrite/create-directory policy, overwrite confirmation, and skipped-save outcomes do not drift between PAC tools.
- the CSV to JSON manifest is now the proof case that the reusable `saveResult` action can opt into the same save-policy metadata as builder-owned output-file parameters.
- the legacy `openContainingFolder` action now uses literal-path resolution, so result paths containing wildcard characters such as brackets behave the same way as the newer output-path actions.
- the Compress Directory script now also uses literal-path handling for its own input, output, and overwrite checks, so bracketed folder names no longer fail inside the tool after passing builder validation.
- picker initial-directory resolution in the shared input helper now also uses literal-path checks, so saved or current file/folder values containing brackets still seed the browse dialog correctly.
- picker browse actions in the shared input helper now recompute their initial directory from the live textbox value on each click, so file and folder tools do not keep reopening from stale window-load paths after the user edits the current path.
- shared PAC config and manifest file I/O now also use literal-path semantics, so tool config reads/writes and manifest loading stay exact-path safe even when the PAC root or tool path contains brackets.
- the Text to Speech script now also uses literal-path handling for generated-output folder and file writes, so `Generate Script` still works when the tool root contains brackets.
- the Text to Speech script now also honors explicitly provided numeric `0` values for `Volume` and `Speed`, so the proof script no longer undercuts the builder's typed-number handling or drop zero-value script-generation lines.
- the shared `openResult` action now resolves local paths and URL-style targets through one helper for both enablement and click behavior, so missing Windows paths no longer appear actionable while URL-based tools such as Google Maps still work.
- the shared `openResult` action is now intentionally narrowed to real local paths or URLs, so arbitrary plain-text results no longer present as openable targets in the current PAC proof cases.
- the shared `openOutput` and `openOutputContainingFolder` actions now resolve saved targets through one existence-aware helper for both enablement and click behavior, so deleted saved files no longer appear actionable.
- the shared `openContainingFolder` action now also uses the shared result-target resolver for both enablement and click behavior, so only existing local filesystem results remain actionable.
- the shared post-run state now keeps display-only `noResultText` separate from actionable result data, so no-result proof tools such as Text to Speech can show completion guidance without enabling `copyResult`, `saveResult`, `openResult`, or `openContainingFolder` on placeholder text alone.
- failed runs in the shared builder now also clear the visible result surface and actionable output state before showing the error dialog, so a new exception cannot leave stale success text, saved-output summaries, or enabled follow-up actions behind from the previous run.
- runs blocked by the shared offline gate now also clear the visible result surface and actionable output state before showing the offline dialog, so a lost connection cannot leave stale success text, saved-output summaries, or enabled follow-up actions behind from the previous run.
- runs blocked by shared parameter validation now also clear the visible result surface and actionable output state before showing the validation dialog, so invalid current inputs cannot leave stale success text, saved-output summaries, or enabled follow-up actions behind from the previous run.
- the shared run catch path now distinguishes true run failures from later post-run failures such as config-save issues, so stale state is still cleared when the run itself fails but fresh result/output state is no longer erased after a successful run has already updated the surface.
- the shared builder now supports opt-in integer-only validation for `Number` parameters, and the Text to Speech manifest is the first proof case so decimal input no longer silently rounds into int-backed script parameters.
- the shared run callback now routes boolean, number, and general parameters through one parameter-processing helper plus one shared validation-dialog helper, so normalization, saved-value persistence, script pass-through, and result-output binding stay aligned across parameter types.
- initial control values now also flow through one shared selector helper, so saved/default config precedence, load-time file-path normalization, and stale `allowedValues` fallback all follow one contract before controls are built.
- explicit saved blank values now also survive reload in that shared selector helper, so clearing an optional field no longer falls back to a default value on the next open.
- the CSV to JSON and Text to Speech proof configs are now aligned with the stronger shared parameter contract, so current defaults and saved values exercise exact parameter names, explicit `false` booleans, numeric values, and blank-string overrides instead of older legacy/null shapes.
- the CSV to JSON manifest is now the first explicit proof case for tool-level saved-output and skipped-output dialog overrides using the shared `{savedOutputSummary}` and `{skippedOutputSummary}` message tokens.
- the Text to Speech manifest is now also the explicit proof case for shared `invalidNumberTitle` and `invalidNumberMessage` dialog overrides after numeric validation handling was centralized.
- the Compress Directory manifest is now also the explicit proof case for the shared generic `invalidValueTitle` and `invalidValueMessage` dialog override path.
- the Google Maps Url manifest is now the explicit proof case for shared `offlineTitle` and `offlineMessage` dialog overrides, even before a network-required PAC tool is introduced.
- the Regex Extractor manifest is now the first proof case for a builder-owned output file that refuses to overwrite an existing file, while CSV to JSON now makes the overwrite-allowed behavior explicit.
- the CSV to JSON manifest is now the first proof case for optional overwrite confirmation on a builder-owned output file, and the Regex Extractor manifest is now the first proof case for enforced `.json` output extensions on manually typed save paths.
- builder-owned save-path fields now reopen in normalized form, so saved output paths stay consistent with auto-appended extensions and the actual write target.
- canceled overwrite prompts and other non-written builder-owned outputs are now surfaced explicitly as skipped outputs in run-state feedback instead of silently disappearing.

What is still incomplete or needs to be restored:

- the child window currently uses a callback-safe backdrop fallback path because acrylic type resolution is not always available in the event callback runspace.
- PAC now has a real self-building tool window path proven by Compress Directory, Google Maps Url, Text to Speech, CSV to JSON, and Regex Extractor, and the current builder hardening pass has closed the main typed-input, validation, and result/action consistency gaps found during that rollout.
- the child window now has a shared callback-safe title-bar setup path in `Shared\New-PacChildWindow.ps1`, but it still needs live PAC runtime proof and any remaining chrome refinements once WinUIShell title-bar styling is validated in the target environment.
- live PAC proof then showed the first shared title-bar path was structurally incomplete because the `TitleBar` control was not yet part of the child window content tree; the shared child-window helper now stores that control and the simple-tool window host mounts it above the tool content in a grid so the custom title bar can actually render.
- live PAC proof then exposed a second layout regression where the mounted title bar reduced available client height and clipped lower controls in fixed-height tool windows; the shared simple-tool host now wraps tool content in a `ScrollViewer` so child-window title-bar adoption does not hide action rows or result surfaces.
- the shared child-window title bar now also accepts a concise subtitle, and simple-tool windows pass the existing manifest `category` into that shared chrome so tool windows read more like PAC windows instead of bare standalone dialogs.
- the shared child-window title bar now also adds a consistent PAC icon through the shared helper, so simple-tool windows pick up one more piece of recognizable PAC chrome without needing per-tool manifest metadata.
- the shared child-window helper now also owns the title-bar content-host pattern through one helper call, so future PAC child windows do not have to duplicate the grid mounting logic that places custom title-bar chrome above scrollable content.
- the shared child-window helper now also owns optional scroll hosting for child-window content, so title-bar-aware PAC windows can opt into non-clipping layouts without each caller duplicating `ScrollViewer` setup.
- PAC does not currently contain a real non-simple custom child window beyond the main shell, so the shared child-window chrome work is now standardized for the existing simple-tool callers and the next meaningful proof point depends on selecting a workflow-heavy tool.

Important implementation rule now proven by failure:

- shared helper files that instantiate WinUIShell callback types such as `EventCallback` must import the required WinUIShell namespace in that helper file itself; they cannot rely on the calling page file to provide that type resolution.

This means the modular direction is correct, but the plan needs to shift from "start the refactor" to "finish and harden the refactor."

## Refactor Strategy For Your Current Script

Do not try to redesign everything in one pass. Refactor in stages.

### ✅ Phase 1: Separate the current Compress Directory UI

Goal:

Move the current `#region PG-Download` behavior out of `start.ps1` while keeping the app behavior the same.

Status:

Mostly complete. The page module, page registry, and direct script execution path now exist.

Steps:

1. ✅ Keep `Pages\Get-CompressDirectoryPage.ps1` as the page module for this tool.
2. ✅ Keep `Compress-Directory.ps1` as the execution layer under `Tools\Compress Directory\`.
3. ✅ Keep page registration in `Pages\Register-PacPages.ps1` and page lookup in `$pageRegistry`.
4. ✅ Preserve metadata-driven `contentPageOnLoaded` behavior in `start.ps1`.
5. ✅ Remove temporary debug tracing from the Compress Directory page after the child window flow is stable.

At the end of this phase, you should be able to delete the current `#region PG-Download` block entirely.

### ✅ Phase 2: Move menu item creation into metadata

Goal:

Stop hardcoding each menu item in `start.ps1`.

Status:

Complete for the current pages, with one design adjustment already learned during testing: a category should only create a dropdown parent when multiple tools actually belong to that category.

Instead of this pattern:

```powershell
$item4 = [NavigationViewItem]::new()
$item4.Content = 'Compress Directory'
...
$navigationView.MenuItems.Add($item4)
```

Use page metadata to generate menu items:

```powershell
foreach ($page in $pageRegistry.Values) {
    $menuItem = New-PacNavigationItem -PageDefinition $page
    $menuItemMap[$page.Name] = $menuItem
    $navigationView.MenuItems.Add($menuItem)
}
```

This is where future growth becomes easier.

Implementation note:

- single-item categories should render as standalone navigation items
- multi-item categories should render as grouped dropdown parents

### 🚧 Phase 3: Introduce shared child-window and dialog helpers

Goal:

Remove repeated code for:

- child window setup
- title bar setup
- centering logic
- content dialogs
- validation messages

Status:

Mostly complete. `Show-PacDialog` exists, `New-PacChildWindow` exists, and the Compress Directory page now uses the shared child-window helper.

The current Compress Directory block repeats dialog creation several times. That should become one helper.

Example helper direction:

```powershell
Show-PacDialog -Title 'Missing Input' -Content 'Please enter an input directory path.' -Owner $childWin
```

Additional helper requirements learned from implementation:

- ✅ restore child window centering relative to the screen that contains the mouse pointer or the main PAC window
- 🚧 restore the same visual setup for child windows each time they are created
- ✅ provide one shared way to size child windows and apply backdrop/title bar behavior
- ✅ ensure any shared helper that creates WinUIShell callback objects imports its required namespaces locally so callback types resolve correctly at runtime

Suggested helper direction now:

```powershell
$childWin = New-PacChildWindow -Title 'Compress Directory' -Width 600 -Height 420 -CenterOnPointerScreen
```

The helper should own:

- ✅ child window creation
- ✅ sizing
- ✅ screen selection
- ✅ centering
- 🚧 default backdrop/theme setup
- 🚧 optional title bar customization
- ✅ its own WinUIShell callback type imports when it creates callback objects internally

The remaining work in this phase is mostly about standardizing child-window chrome and optional title-bar behavior.

### ✅ Phase 3A: Restore PAC Visual Consistency

Goal:

Make tool pages visually match the rest of the shell instead of looking like flat, isolated content panels.

Required fixes:

1. ✅ Ensure every page sets transparent backgrounds for the page surface and its root layout panel when needed.
2. ✅ Recheck the current `contentPageOnLoaded` path so page modules do not accidentally override the shell's acrylic/translucent look with opaque containers.
3. ✅ Add one shared page-surface helper or convention so future pages inherit the same look by default.
4. ✅ Verify the Compress Directory page visually matches the rest of PAC after navigation.

Implementation direction:

```powershell
$page.Background = [SolidColorBrush]::new([Colors]::Transparent)
$panel.Background = [SolidColorBrush]::new([Colors]::Transparent)
```

This should be treated as a shell-level UX requirement, not a page-by-page optional style.

### ⏳ Phase 4: Add data-driven tools for common script shapes

Goal:

For tools that only need simple parameter forms, do not hand-build every UI.

Target end state:

PAC should be able to create a mostly self-building tool window from `tool.json` metadata for common tools.

That means a simple tool should be able to declare:

- parameters to render
- validation rules
- primary action text
- result presentation
- optional follow-up actions such as copy, open, or export

without requiring a fully custom page file for each one.

Create a standard tool definition shape such as:

```powershell
@{
    Name = 'Compress Directory'
    ToolPath = "$PSScriptRoot\Tools\Compress Directory"
    ScriptPath = "$PSScriptRoot\Tools\Compress Directory\Compress-Directory.ps1"
    ConfigPath = "$PSScriptRoot\Tools\Compress Directory\config.json"
    InputPath = "$PSScriptRoot\Tools\Compress Directory\input"
    TempPath = "$PSScriptRoot\Tools\Compress Directory\temp"
    OutputPath = "$PSScriptRoot\Tools\Compress Directory\output"
    EntryCommand = 'Compress-Directory'
    Parameters = @(
        @{ Name = 'InputDirectory'; Type = 'Folder'; Label = 'Input Directory Path'; Required = $true }
        @{ Name = 'OutputDirectory'; Type = 'Folder'; Label = 'Output Directory Path'; Required = $true }
    )
    Output = 'None'
}
```

Then build the form automatically from metadata.

This is the best long-term answer if you expect many utilities that differ mostly by parameters.

The Google Maps Url tool is a good example of the kind of page that should eventually become mostly self-building: one input, one primary action, one result surface, and a small set of follow-up actions.

The Text to Speech tool is now the second concrete proof case for this direction. It adds pressure on the builder for multiline text input, boolean inputs, optional typed parameters, and tools that can succeed without returning a result unless an explicit "resume" style option is enabled.

The next hardening step inside this phase should move past `Number` and focus on the remaining typed-input contract details, result behavior, and common actions.

Complex tools should not be forced into that contract. When a tool has many parameters, grouped sections, conditional inputs, multi-step execution, progress reporting, or richer output behavior, it should keep a custom page module and child-window implementation while still reusing shared PAC helpers.

This means PAC should evolve by extending the simple-tool builder only when a capability is broadly reusable, while preserving the custom-tool lane for anything that does not naturally fit the simple manifest-driven model.

## Minimal Change Design For Right Now

If you want the smallest possible improvement without a full registry yet, do this first:

1. ✅ Create `Pages\Get-CompressDirectoryPage.ps1`.
2. ✅ Put the current child window code in a function like `Show-CompressDirectoryWindow`.
3. ❌ In `start.ps1`, replace the current hardcoded region with one function call:

```powershell
if ($pageName -eq 'Compress Directory') {
    $openToolCallback = [EventCallback]::new()
    $openToolCallback.ScriptBlock = {
        Show-CompressDirectoryWindow
    }
    $button.AddClick($openToolCallback)
}
```

That is not the final architecture, but it is a good first cut because it immediately removes the largest block of tool-specific code from the shell.

## Better Final Design

The better end state is this:

- `start.ps1` builds shell and handles navigation only.
- page modules define page behavior.
- tool directories hold the actual script logic, config, temp files, and outputs.
- shared helpers manage dialogs, windows, and common controls.
- optional JSON metadata describes parameter-driven tools.

## Practical Example Of The First Refactor

### ✅ Step A: start.ps1 responsibilities

Keep only:

- imports
- `$appContext`
- `$pageRegistry`
- generic `Navigate`
- generic `contentPageOnLoaded`
- menu generation
- app startup

### 🚧 Step B: Compress page responsibilities

Move into a separate file:

- ✅ open child window
- ✅ create labels and textboxes
- ✅ validate input
- ✅ show dialogs
- ✅ run `Tools\Compress Directory\Compress-Directory.ps1`
- ⏳ optionally read defaults from `Tools\Compress Directory\config.json`

### 🚧 Step C: Shared helper responsibilities

Move common logic into helpers:

- ✅ show content dialog
- ✅ center child window
- ✅ apply shared child window construction
- ⏳ create standard title bar
- ⏳ maybe create labeled input rows

## Naming Recommendations

Use predictable names so new tools are easy to add.

Suggested conventions:

- page definitions: `Get-<ToolName>Page`
- window launchers: `Show-<ToolName>Window`
- shared UI helpers: `New-Pac*`, `Show-Pac*`, `Invoke-Pac*`
- tool folders: user-friendly folder names under `Tools\`
- execution scripts: verb-noun names only inside each tool folder

Examples:

- `Get-CompressDirectoryPage`
- `Show-CompressDirectoryWindow`
- `Show-PacDialog`
- `New-PacChildWindow`
- `Tools\Compress Directory\Compress-Directory.ps1`

## Accuracy Check

This plan now matches the current direction of PAC more closely:

- one tool can live entirely inside `Tools\<Tool Name>\`
- tool folders can own `input\`, `temp\`, and `output\`
- page files remain separate from execution files
- shared helpers remain outside the tool folder so common UI code does not get duplicated

Additional facts now proven by implementation:

- PAC is already using metadata-driven page registration and metadata-driven navigation item creation
- PAC already supports `Home`, `Compress Directory`, `Google Maps Url`, and `Text to Speech` as registered pages
- page navigation is now event-driven through the NavigationView item callback
- the Compress Directory execution script must be runnable directly as a script, not only as a function definition file
- the Google Maps Url tool confirms a second tool can follow the same manifest/config/page pattern while using a different parameter set and different post-run actions
- the Text to Speech tool confirms the self-building path now has to support multiline text input, boolean inputs, and successful no-result execution paths
- the Text to Speech tool also proves that config defaults for boolean inputs must be stored as real booleans, not empty strings
- the shared builder now validates and converts `Number` inputs before script execution and config persistence, rather than relying on PowerShell to coerce strings later
- the shared child-window helper now includes a safe backdrop fallback for callback contexts where acrylic type resolution is unavailable
- the shared simple-tool window helper must import `using namespace WinUIShell` in its own file scope because callback type resolution does not safely flow in from the calling page file

What is still intentionally flexible:

- whether `config.json` is per-tool or generated later
- where the boundary should sit between simple self-building tools and custom workflow-heavy tools

That flexibility is fine. The important part is that the directory contract, required manifest, and app boundaries are now consistent.

## Risks To Avoid

### 1. Do not let page files depend on hidden globals

Avoid direct dependence on:

- `$win`
- `$resources`
- `$frame`
- `$childGrid`

Pass these in through a context object.

### 2. Do not mix tool registration with UI building logic everywhere

Adding a tool should require one registration point, not edits in multiple unrelated sections.

### 3. Do not over-engineer metadata too early

Start by modularizing one real page first. Once that works, decide whether more pages are custom or parameter-driven.

### 4. Do not assume helper type resolution will come from the caller

If a shared helper creates WinUIShell objects such as `EventCallback`, `Window`, or other UI types directly, import the required namespaces in that helper file.

Do not rely on the page module that calls the helper to make those types available indirectly.

## Recommended Next Implementation Order

Reading rule:

- the current next step is the first item in this list that is not marked `✅`
- do not treat earlier completed items as pending work just because they appear above active items

1. ✅ Add manifest-backed metadata to `Tools\Compress Directory\tool.json` and start reading from it instead of leaving it empty.
2. ✅ Add `ToolPath`, `ScriptPath`, `ConfigPath`, `InputPath`, `TempPath`, and `OutputPath` into the page definition or manifest-backed tool definition.
3. ✅ Start reading defaults or saved values from `config.json` into the Compress Directory tool UI.
4. ✅ Decide whether PAC should write updated values back to `config.json` after a successful run.
5. ✅ Broaden the self-building tool window contract for simple tools now that Compress Directory, Google Maps Url, Text to Speech, CSV to JSON, and Regex Extractor all use it.
6. ✅ Create standard child-window title-bar behavior in the shared helper once callback-safe styling is finalized.
7. ✅ Create shared labeled-input helpers for common tool forms.
8. ✅ After two or three tools exist, decide whether to build JSON-driven parameter forms for simple tools.
9. ✅ Tighten the manifest contract for the remaining typed-input rules, plus any remaining no-result success behavior and common actions in `Shared\Show-PacSimpleToolWindow.ps1` now that `saveResult` and builder-owned output files share one save path.
10. ⏳ When the first workflow-heavy tool arrives, implement it as a custom page that reuses PAC shared helpers to validate the two-lane architecture.

## Bottom Line

Yes, the current region should be moved to a separate file.

The best pattern is not just dot-sourcing a loose script block. The better pattern is:

- separate page file
- exported page function
- explicit app context
- central registry
- shared helpers for repeated UI work

That will keep PAC easy to enhance as more PowerShell tools are added.

The immediate cleanup priorities are now:

- keep the shared child-window chrome helper stable as the baseline for current PAC tool windows
- keep the shared self-building manifest contract stable unless a real tool exposes another concrete gap
- keep the first genuinely complex tool on a custom page path so PAC proves both simple and complex tool models
- use that first workflow-heavy tool to validate where the boundary should sit between reusable PAC helpers and custom workflow-specific UI
