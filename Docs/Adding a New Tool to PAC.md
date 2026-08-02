# Adding a New Tool to PAC

This document explains the current PAC tool-registration flow exactly as the repository works today.

Use this when you want to add a new tool to PAC without guessing how the shell, page registration, tool manifest, and shared tool window builder fit together.

## Choose the Right Path

PAC currently supports two practical ways to add a tool.

## Option 1: Standard Simple Tool

Use the standard simple-tool path when your tool can be expressed as:

- a PowerShell script with named parameters
- a manifest-driven form
- a single run action
- a result box and optional result actions

This is the default and preferred path for most PAC tools.

Current proof cases in the repo:

- Compress Directory
- CSV to JSON
- Google Maps Url
- Regex Extractor
- Text to Speech

## Option 2: Custom Page or Custom Window

Use the custom path when your tool needs more than the shared simple-tool builder can reasonably provide.

Typical reasons:

- multi-step workflows
- complex layouts
- custom navigation behavior
- live progress surfaces that do not fit the standard result box model
- workflow-specific interactions that are awkward in a manifest

> [!Important] 
> 
> PAC is intentionally a two-lane system. Do not force every future tool into the simple manifest-driven builder if the workflow is truly custom.

## Standard Simple Tool: Exact Steps

## 1. Create the Tool Folder

Create a new folder under `Tools/`.

Example:

```text
Tools/
|- My New Tool/
   |- My-NewTool.ps1
   |- tool.json
   |- config.json
   |- input/
   |- temp/
   |- output/
```

Notes:

- `tool.json` is the manifest PAC reads to build the tool window.
- `config.json` stores defaults and saved values.
- `input`, `temp`, and `output` should exist up front because PAC manifests commonly refer to them.

## 2. Write the Tool Script

The script should expose one real function and then invoke that function through `@PSBoundParameters`.

This is the current PAC pattern and avoids duplicating business logic outside the function.

Template:

```powershell
param(
    [Parameter(Mandatory)]
    [string]$Text,

    [string]$Mode
)

function Invoke-MyNewTool {
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [string]$Mode
    )

    return "Tool output for: $Text ($Mode)"
}

if ($PSBoundParameters.Count -gt 0) {
    Invoke-MyNewTool @PSBoundParameters
}
```

Rules:

- The function name should match `entryCommand` in `tool.json`.
- Parameter names in the script must match the parameter `name` values in `tool.json`.
- Return plain text, objects, arrays, or JSON text as appropriate for the tool.

## 3. Create `tool.json`

This is the core registration contract for a simple tool.

Minimal example:

```json
{
  "name": "My New Tool",
  "category": "Utilities",
  "description": "Describe exactly what the tool does.",
  "toolPath": "Tools/My New Tool",
  "scriptPath": "Tools/My New Tool/My-NewTool.ps1",
  "configPath": "Tools/My New Tool/config.json",
  "inputPath": "Tools/My New Tool/input",
  "tempPath": "Tools/My New Tool/temp",
  "outputPath": "Tools/My New Tool/output",
  "entryCommand": "Invoke-MyNewTool",
  "requiresNetwork": false,
  "window": {
    "title": "My New Tool",
    "width": 680,
    "height": 520
  },
  "ui": {
    "primaryActionText": "Run Tool",
    "result": {
      "label": "Result",
      "placeholder": "Tool output will appear here.",
      "minHeight": 120
    },
    "actions": [
      {
        "kind": "copyResult",
        "label": "Copy Result"
      }
    ]
  },
  "parameters": [
    {
      "name": "Text",
      "type": "String",
      "control": "TextArea",
      "multiline": true,
      "minHeight": 140,
      "label": "Input Text",
      "required": true,
      "description": "Enter the text to process."
    },
    {
      "name": "Mode",
      "type": "String",
      "label": "Mode",
      "allowedValues": [
        "basic",
        "advanced"
      ],
      "description": "Choose the run mode."
    }
  ]
}
```

## 4. Create `config.json`

PAC expects the current config shape used by the existing tools.

Template:

```json
{
  "defaults": {
    "Text": "",
    "Mode": "basic"
  },
  "savedValues": {
    "Text": "",
    "Mode": ""
  }
}
```

Notes:

- `defaults` are initial tool values.
- `savedValues` store last-used values.
- Keep parameter names aligned with the manifest.

## 5. Create the Page File

Create a new page under `Pages/`.

Example file:

```text
Pages/Get-MyNewToolPage.ps1
```

Template:

```powershell
using namespace WinUIShell
using namespace WinUIShell.Microsoft.UI
using namespace WinUIShell.Microsoft.UI.Xaml
using namespace WinUIShell.Microsoft.UI.Xaml.Controls
using namespace WinUIShell.Microsoft.UI.Xaml.Media

function Get-MyNewToolPage {
    param([hashtable]$Context)

    $toolManifest = Get-PacToolManifest -RootPath $Context.RootPath -ManifestPath 'Tools/My New Tool/tool.json'

    return @{
        Name        = $toolManifest.name
        MenuText    = $toolManifest.name
        Category    = $toolManifest.category
        ToolPath    = $toolManifest.toolPath
        ScriptPath  = $toolManifest.scriptPath
        ConfigPath  = $toolManifest.configPath
        InputPath   = $toolManifest.inputPath
        TempPath    = $toolManifest.tempPath
        OutputPath  = $toolManifest.outputPath
        Parameters  = $toolManifest.parameters
        Description = $toolManifest.description

        Icon = @{
            Type       = 'FontIcon'
            Glyph      = [char]0xE70F
            FontFamily = 'Segoe MDL2 Assets'
        }

        OnLoaded = {
            param($pageName, $page, $e, $pageContext)

            if ($page.Content) { return }

            $panel = [StackPanel]::new()
            $panel.Margin = 32
            $panel.Spacing = 16

            Set-PacPageSurface -Page $page -Panel $panel

            $title = [TextBlock]::new()
            $title.Text = $toolManifest.name
            $title.Style = $pageContext.Resources['TitleTextBlockStyle']

            $text = [TextBlock]::new()
            $text.Text = $toolManifest.description
            $text.Style = $pageContext.Resources['BodyTextBlockStyle']

            $button = [Button]::new()
            $button.Content = 'Open Tool'
            $button.Style = $pageContext.Resources['AccentButtonStyle']

            $openToolCallback = [EventCallback]::new()
            $openToolCallback.ScriptBlock = {
                Show-MyNewToolWindow
            }
            $button.AddClick($openToolCallback)

            $panel.Children.Add($title)
            $panel.Children.Add($text)
            $panel.Children.Add($button)

            $page.Content = $panel
        }
    }
}

function Show-MyNewToolWindow {
    $toolManifest = Get-PacToolManifest -RootPath $script:PacRootPath -ManifestPath 'Tools/My New Tool/tool.json'
    Show-PacSimpleToolWindow -ToolManifest $toolManifest | Out-Null
}
```

## 6. Register the Page

Add the page function to `Pages/Register-PacPages.ps1`.

Example:

```powershell
function Register-PacPages {
    param([hashtable]$Context)

    return @(
        Get-HomePage -Context $Context
        Get-CompressDirectoryPage -Context $Context
        Get-GoogleMapsUrlPage -Context $Context
        Get-RegexExtractorPage -Context $Context
        Get-TextToSpeechPage -Context $Context
        Get-CSVToJSONPage -Context $Context
        Get-MyNewToolPage -Context $Context
    )
}
```

If you skip this step, the tool will never appear in PAC.

## 7. Run and Validate

Validate the new tool in this order:

1. Confirm the page appears in the PAC navigation.
2. Confirm the tool window opens.
3. Confirm each parameter renders as expected.
4. Confirm validation messages are correct.
5. Confirm the script runs with the expected parameter set.
6. Confirm result actions behave correctly.
7. Confirm config values save and reload correctly.

## Supported Manifest Options

The shared simple-tool builder already supports the options below.

## Top-Level Manifest Properties

- `name`
- `category`
- `description`
- `toolPath`
- `scriptPath`
- `configPath`
- `inputPath`
- `tempPath`
- `outputPath`
- `entryCommand`
- `requiresNetwork`
- `offlineMessage`
- `window`
- `ui`
- `parameters`

## Window Options

Supported under `window`:

- `title`
- `width`
- `height`

The shared child window also uses the tool `category` as the subtitle.

## UI Options

Supported under `ui`:

- `primaryActionText`
- `dialogs`
- `result`
- `actions`

## Dialog Options

Currently supported under `ui.dialogs`:

- `offlineTitle`
- `offlineMessage`
- `invalidNumberTitle`
- `invalidNumberMessage`
- `invalidValueTitle`
- `invalidValueMessage`
- `savedOutputTitle`
- `savedOutputMessage`
- `skippedOutputTitle`
- `skippedOutputMessage`
- `noResultTitle`
- `noResultMessage`
- `successTitle`
- `successMessage`

## Result Options

Currently supported under `ui.result`:

- `label`
- `format`
- `jsonDepth`
- `placeholder`
- `minHeight`
- `noResultText`
- `savedOutputText`

`format` is especially useful for JSON-oriented tools.

## Action Kinds

The simple-tool builder currently supports these `ui.actions[].kind` values:

- `copyResult`
- `saveResult`
- `openResult`
- `openContainingFolder`
- `openOutput`
- `openOutputContainingFolder`

Action entries also support labels and per-action dialog text such as:

- `label`
- `title`
- `filter`
- `fileName`
- `defaultExtension`
- `initialDirectory`
- `initialDirectoryProperty`
- `successTitle`
- `successMessage`
- `skippedTitle`
- `skippedMessage`
- `noResultTitle`
- `noResultMessage`
- `errorTitle`

For save actions, PAC also supports overwrite and directory behavior flags such as:

- `overwriteExisting`
- `confirmOverwrite`
- `confirmOverwriteTitle`
- `confirmOverwriteMessage`
- `createParentDirectories`
- `appendDefaultExtension`

## Parameter Options

Each entry in `parameters` can use the following current options.

## Core Fields

- `name`
- `type`
- `label`
- `description`
- `required`

## Supported Types

- `String`
- `Number`
- `Boolean`
- `File`
- `Folder`

## Rendering Behavior

- `Boolean` renders as a checkbox.
- `allowedValues` renders as a combo box.
- `control: "TextArea"` or `multiline: true` renders a multiline text box.
- `File` and `Folder` can render picker-backed text inputs.
- `Number` uses numeric parsing and can enforce integer-only input.

## Validation and Input Options

- `allowedValues`
- `minLength`
- `maxLength`
- `min`
- `max`
- `integerOnly`
- `multiline`
- `minHeight`
- `validationMessages`

Known validation message keys include:

- `required`
- `allowedValues`
- `invalidNumber`
- `integer`
- `min`
- `max`
- `minLength`
- `maxLength`
- `fileAlreadyExists`
- `invalidFileExtension`

## File Import Support

Text inputs can optionally import file contents into the field with `fileImport`.

Supported `fileImport` keys include:

- `label`
- `title`
- `filter`
- `initialDirectory`
- `initialDirectoryProperty`

## Path Picker Support

File and folder parameters can use `pathPicker`.

Supported `pathPicker` keys include:

- `label`
- `title`
- `mode`
- `filter`
- `defaultExtension`
- `fileName`
- `initialDirectory`
- `initialDirectoryProperty`
- `checkFileExists`
- `showNewFolderButton`

`mode` is typically `open` or `save`.

## Result Output Support

File parameters can optionally save the tool result automatically with `resultOutput`.

Supported `resultOutput` keys include:

- `content`
- `appendDefaultExtension`
- `enforceDefaultExtension`
- `overwriteExisting`
- `confirmOverwrite`
- `confirmOverwriteTitle`
- `confirmOverwriteMessage`
- `createParentDirectories`
- `passToScript`

Important behavior:

- If a parameter has `resultOutput`, PAC treats it as a builder-owned output binding.
- By default, that parameter is not passed to the script.
- Set `passToScript` to `true` only if the script itself also needs that parameter value.
- `content` currently supports `formatted` and `raw`, with `formatted` as the default behavior.

## Optional Custom Tool Path

Choose the custom path when the simple-tool builder is no longer the right abstraction.

Typical approach:

1. Create a page file in `Pages/`.
2. Register it in `Pages/Register-PacPages.ps1`.
3. Build your own `OnLoaded` content instead of only showing an Open Tool button.
4. If needed, open a custom child window with `New-PacChildWindow`.
5. Use `Set-PacChildWindowContent` for title-bar-aware layout and optional scroll hosting.
6. Reuse shared helpers like `Show-PacDialog` or `Get-PacToolManifest` where they still fit.

Important: PAC currently has strong proof for the simple-tool lane and only limited proof for truly custom child-window workflows beyond the main shell. Use the custom path when it is justified, but keep it deliberate.

## Common Mistakes

- Forgetting to register the new page in `Pages/Register-PacPages.ps1`.
- Using parameter names in `tool.json` that do not match the script parameter names.
- Duplicating script logic outside the real tool function instead of using `@PSBoundParameters`.
- Forgetting to create `config.json` with both `defaults` and `savedValues`.
- Assuming a `resultOutput` parameter is automatically passed to the script.
- Forgetting that shared helpers using `EventCallback` must import the WinUIShell namespaces they need in that helper file.
- Choosing the simple-tool lane for a workflow that is already clearly too custom for a manifest.

## Recommended Build Order

For a new PAC tool, the safest order is:

1. Write and validate the standalone script first.
2. Add `tool.json` and `config.json`.
3. Add the page file.
4. Register the page.
5. Launch PAC and validate the tool window.
6. Add advanced actions, picker behavior, or result-output support last.

That order keeps failures local and makes PAC integration easier to debug.