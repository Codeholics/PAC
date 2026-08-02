using namespace WinUIShell
using namespace WinUIShell.Microsoft.UI.Xaml
using namespace WinUIShell.Microsoft.UI.Xaml.Controls

function Test-PacToolValuePresent {
    param(
        [AllowNull()]
        $Value,

        [string]$ParameterType = 'String'
    )

    if ($ParameterType -eq 'Boolean') {
        return $null -ne $Value
    }

    return $null -ne $Value -and -not [string]::IsNullOrWhiteSpace([string]$Value)
}

function Get-PacToolConfigValue {
    param(
        [AllowNull()]
        $Values,

        [Parameter(Mandatory)]
        [string]$ParameterName
    )

    if ($null -eq $Values) {
        return $null
    }

    if ($Values.PSObject.Properties.Name -contains $ParameterName) {
        return $Values.($ParameterName)
    }

    $legacyParameterName = '{0}{1}' -f $ParameterName.Substring(0, 1).ToLowerInvariant(), $ParameterName.Substring(1)
    if ($Values.PSObject.Properties.Name -contains $legacyParameterName) {
        return $Values.($legacyParameterName)
    }

    return $null
}

function Test-PacToolConfigHasEntry {
    param(
        [AllowNull()]
        $Values,

        [Parameter(Mandatory)]
        [string]$ParameterName
    )

    if ($null -eq $Values) {
        return $false
    }

    if ($Values.PSObject.Properties.Name -contains $ParameterName) {
        return $true
    }

    $legacyParameterName = '{0}{1}' -f $ParameterName.Substring(0, 1).ToLowerInvariant(), $ParameterName.Substring(1)
    return $Values.PSObject.Properties.Name -contains $legacyParameterName
}

function ConvertFrom-PacNumberInput {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    $trimmedValue = $Value.Trim()

    $integerValue = 0
    if ([int]::TryParse($trimmedValue, [ref]$integerValue)) {
        return $integerValue
    }

    $numberStyles = [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands
    $decimalValue = 0.0

    if ([double]::TryParse($trimmedValue, $numberStyles, [System.Globalization.CultureInfo]::CurrentCulture, [ref]$decimalValue)) {
        return $decimalValue
    }

    if ([double]::TryParse($trimmedValue, $numberStyles, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$decimalValue)) {
        return $decimalValue
    }

    throw "Enter a valid number for this field."
}

function Test-PacControlHasTextProperty {
    param(
        [AllowNull()]
        $Control
    )

    return $null -ne $Control -and ($Control.PSObject.Properties.Name -contains 'Text')
}

function Test-PacControlIsComboBox {
    param(
        [AllowNull()]
        $Control
    )

    if ($null -eq $Control) {
        return $false
    }

    $type = $Control.GetType()
    if ($null -ne $type -and $type.Name -eq 'ComboBox') {
        return $true
    }

    return ($Control.PSObject.Properties.Name -contains 'SelectedItem')
}

function Test-PacAllowedValue {
    param(
        [AllowNull()]
        $Value,

        [Parameter(Mandatory)]
        $AllowedValues
    )

    foreach ($allowedValue in @($AllowedValues)) {
        if ([string]$allowedValue -ceq [string]$Value) {
            return $true
        }
    }

    return $false
}

function Get-PacValidationMessage {
    param(
        [Parameter(Mandatory)]
        $ParameterDefinition,

        [Parameter(Mandatory)]
        [string]$Rule,

        [Parameter(Mandatory)]
        [string]$DefaultMessage
    )

    if (($ParameterDefinition.PSObject.Properties.Name -contains 'validationMessages') -and $ParameterDefinition.validationMessages) {
        $validationMessages = $ParameterDefinition.validationMessages
        if ($validationMessages.PSObject.Properties.Name -contains $Rule) {
            $customMessage = $validationMessages.$Rule
            if (-not [string]::IsNullOrWhiteSpace([string]$customMessage)) {
                return [string]$customMessage
            }
        }
    }

    return $DefaultMessage
}

function Get-PacCustomText {
    param(
        [AllowNull()]
        $Source,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [Parameter(Mandatory)]
        [string]$DefaultValue
    )

    if ($null -ne $Source -and ($Source.PSObject.Properties.Name -contains $PropertyName)) {
        $customValue = $Source.$PropertyName
        if (-not [string]::IsNullOrWhiteSpace([string]$customValue)) {
            return [string]$customValue
        }
    }

    return $DefaultValue
}

function Get-PacToolDialogText {
    param(
        [AllowNull()]
        $DialogConfig,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [Parameter(Mandatory)]
        [string]$DefaultValue
    )

    return Get-PacCustomText -Source $DialogConfig -PropertyName $PropertyName -DefaultValue $DefaultValue
}

function Resolve-PacActionDirectory {
    param(
        [AllowNull()]
        $ActionConfig,

        [AllowNull()]
        $ToolManifest,

        [AllowNull()]
        $ResultText
    )

    if ($ActionConfig) {
        if (($ActionConfig.PSObject.Properties.Name -contains 'initialDirectoryProperty') -and $ToolManifest) {
            $propertyName = [string]$ActionConfig.initialDirectoryProperty
            if ($ToolManifest.PSObject.Properties.Name -contains $propertyName) {
                return [string]$ToolManifest.$propertyName
            }
        }

        if (($ActionConfig.PSObject.Properties.Name -contains 'initialDirectory') -and $ActionConfig.initialDirectory) {
            if ([System.IO.Path]::IsPathRooted([string]$ActionConfig.initialDirectory) -or -not $ToolManifest -or -not $ToolManifest.toolPath) {
                return [string]$ActionConfig.initialDirectory
            }

            return [System.IO.Path]::GetFullPath((Join-Path -Path $ToolManifest.toolPath -ChildPath $ActionConfig.initialDirectory))
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$ResultText)) {
            $resultPath = [string]$ResultText

            if (Test-Path -LiteralPath $resultPath) {
                if (Test-Path -LiteralPath $resultPath -PathType Container) {
                    return $resultPath
                }

                return Split-Path -Path $resultPath -Parent
            }
        }
    }

    return $null
}

function Get-PacActionOutputPath {
    param(
        [AllowNull()]
        $ActionConfig,

        [AllowNull()]
        $OutputFiles
    )

    if ($null -eq $OutputFiles) {
        return $null
    }

    if ($ActionConfig -and ($ActionConfig.PSObject.Properties.Name -contains 'outputParameterName') -and $ActionConfig.outputParameterName) {
        $parameterName = [string]$ActionConfig.outputParameterName
        if ($OutputFiles.ContainsKey($parameterName) -and -not [string]::IsNullOrWhiteSpace([string]$OutputFiles[$parameterName])) {
            return [string]$OutputFiles[$parameterName]
        }
    }

    foreach ($key in $OutputFiles.Keys) {
        if (-not [string]::IsNullOrWhiteSpace([string]$OutputFiles[$key])) {
            return [string]$OutputFiles[$key]
        }
    }

    return $null
}

function Resolve-PacOpenResultTarget {
    param(
        [AllowNull()]
        [string]$ResultText
    )

    if ([string]::IsNullOrWhiteSpace($ResultText)) {
        return [pscustomobject]@{
            Kind   = 'missing'
            Target = $null
        }
    }

    $candidate = [string]$ResultText
    if (Test-Path -LiteralPath $candidate) {
        return [pscustomobject]@{
            Kind   = 'path'
            Target = (Get-Item -LiteralPath $candidate).FullName
        }
    }

    if ([System.IO.Path]::IsPathRooted($candidate) -or $candidate.Contains('\')) {
        return [pscustomobject]@{
            Kind   = 'missingPath'
            Target = $candidate
        }
    }

    $uri = $null
    if ([System.Uri]::TryCreate($candidate, [System.UriKind]::Absolute, [ref]$uri)) {
        return [pscustomobject]@{
            Kind   = 'uri'
            Target = $candidate
        }
    }

    if ($candidate.Contains('/')) {
        return [pscustomobject]@{
            Kind   = 'missingPath'
            Target = $candidate
        }
    }

    return [pscustomobject]@{
        Kind   = 'unsupported'
        Target = $candidate
    }
}

function Resolve-PacOutputActionTarget {
    param(
        [AllowNull()]
        $ActionConfig,

        [AllowNull()]
        $OutputFiles
    )

    $outputPath = Get-PacActionOutputPath -ActionConfig $ActionConfig -OutputFiles $OutputFiles
    if ([string]::IsNullOrWhiteSpace([string]$outputPath)) {
        return [pscustomobject]@{
            Kind   = 'missing'
            Target = $null
        }
    }

    if (-not (Test-Path -LiteralPath $outputPath)) {
        return [pscustomobject]@{
            Kind   = 'missingPath'
            Target = [string]$outputPath
        }
    }

    return [pscustomobject]@{
        Kind   = 'path'
        Target = (Get-Item -LiteralPath $outputPath).FullName
    }
}

function Test-PacActionHasTarget {
    param(
        [AllowNull()]
        $ActionConfig,

        [AllowNull()]
        [string]$ResultText,

        [AllowNull()]
        $OutputFiles
    )

    $actionKind = if ($ActionConfig -and ($ActionConfig.PSObject.Properties.Name -contains 'kind')) {
        [string]$ActionConfig.kind
    } else {
        ''
    }

    switch ($actionKind) {
        'openResult' {
            $openTarget = Resolve-PacOpenResultTarget -ResultText $ResultText
            return $openTarget.Kind -eq 'path' -or $openTarget.Kind -eq 'uri'
        }
        'openContainingFolder' {
            $openTarget = Resolve-PacOpenResultTarget -ResultText $ResultText
            return $openTarget.Kind -eq 'path'
        }
        'openOutput' {
            $outputTarget = Resolve-PacOutputActionTarget -ActionConfig $ActionConfig -OutputFiles $OutputFiles
            return $outputTarget.Kind -eq 'path'
        }
        'openOutputContainingFolder' {
            $outputTarget = Resolve-PacOutputActionTarget -ActionConfig $ActionConfig -OutputFiles $OutputFiles
            return $outputTarget.Kind -eq 'path'
        }
        default {
            return -not [string]::IsNullOrWhiteSpace($ResultText)
        }
    }
}

function Reset-PacRunSurfaceState {
    param(
        [AllowNull()]
        $ResultBox,

        [AllowNull()]
        $StatusBlock,

        [AllowNull()]
        $ActionButtons,

        [AllowNull()]
        $ActionStates,

        [switch]$ClearResultDisplay
    )

    if ($ClearResultDisplay -and $ResultBox) {
        $ResultBox.Text = ''
    }

    if ($StatusBlock) {
        $StatusBlock.Text = ''
    }

    foreach ($actionState in @($ActionStates)) {
        if ($actionState) {
            $actionState.CurrentResultText = ''
            $actionState.OutputFiles = @{}
        }
    }

    foreach ($button in @($ActionButtons)) {
        if ($button) {
            $button.IsEnabled = $false
        }
    }
}

function Get-PacSavedOutputSummary {
    param(
        [AllowNull()]
        $OutputFiles
    )

    $savedPaths = @()
    if ($OutputFiles) {
        foreach ($key in $OutputFiles.Keys) {
            if (-not [string]::IsNullOrWhiteSpace([string]$OutputFiles[$key])) {
                $savedPaths += [string]$OutputFiles[$key]
            }
        }
    }

    if ($savedPaths.Count -eq 0) {
        return $null
    }

    $distinctPaths = @($savedPaths | Select-Object -Unique)
    if ($distinctPaths.Count -eq 1) {
        return [pscustomobject]@{
            Count       = 1
            Paths       = $distinctPaths
            DisplayText = "Saved output: $($distinctPaths[0])"
        }
    }

    $pathList = $distinctPaths | ForEach-Object { "- $_" }
    return [pscustomobject]@{
        Count       = $distinctPaths.Count
        Paths       = $distinctPaths
        DisplayText = "Saved outputs:`r`n$($pathList -join "`r`n")"
    }
}

function Get-PacSkippedOutputSummary {
    param(
        [AllowNull()]
        $SkippedOutputs
    )

    $skippedItems = @()
    if ($SkippedOutputs) {
        foreach ($item in @($SkippedOutputs)) {
            if ($item -and -not [string]::IsNullOrWhiteSpace([string]$item.Path)) {
                $skippedItems += $item
            }
        }
    }

    if ($skippedItems.Count -eq 0) {
        return $null
    }

    $displayLines = foreach ($item in $skippedItems) {
        $reasonText = switch ([string]$item.Reason) {
            'overwriteCanceled' { 'overwrite canceled' }
            'noContent' { 'no output content' }
            default { 'not written' }
        }

        "- $($item.Path) ($reasonText)"
    }

    return [pscustomobject]@{
        Count       = $skippedItems.Count
        Paths       = @($skippedItems | ForEach-Object { [string]$_.Path })
        Reasons     = @($skippedItems | ForEach-Object { [string]$_.Reason })
        DisplayText = "Skipped outputs:`r`n$($displayLines -join "`r`n")"
    }
}

function Expand-PacMessageTemplate {
    param(
        [Parameter(Mandatory)]
        [string]$Template,

        [AllowNull()]
        $SavedOutputSummary,

        [AllowNull()]
        $SkippedOutputSummary
    )

    $expandedText = $Template
    if ($SavedOutputSummary) {
        $expandedText = $expandedText.Replace('{savedOutputCount}', [string]$SavedOutputSummary.Count)
        $expandedText = $expandedText.Replace('{savedOutputPaths}', [string]($SavedOutputSummary.Paths -join "`r`n"))
        $expandedText = $expandedText.Replace('{savedOutputSummary}', [string]$SavedOutputSummary.DisplayText)
    }

    if ($SkippedOutputSummary) {
        $expandedText = $expandedText.Replace('{skippedOutputCount}', [string]$SkippedOutputSummary.Count)
        $expandedText = $expandedText.Replace('{skippedOutputPaths}', [string]($SkippedOutputSummary.Paths -join "`r`n"))
        $expandedText = $expandedText.Replace('{skippedOutputSummary}', [string]$SkippedOutputSummary.DisplayText)
    }

    return $expandedText
}

function Get-PacOptionalText {
    param(
        [AllowNull()]
        $Source,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    if ($null -ne $Source -and ($Source.PSObject.Properties.Name -contains $PropertyName) -and $null -ne $Source.$PropertyName) {
        return [string]$Source.$PropertyName
    }

    return ''
}

function Format-PacToolResult {
    param(
        [AllowNull()]
        $Result,

        [AllowNull()]
        $ResultConfig
    )

    if ($null -eq $Result) {
        return ''
    }

    $format = if ($ResultConfig -and ($ResultConfig.PSObject.Properties.Name -contains 'format') -and $ResultConfig.format) {
        [string]$ResultConfig.format
    } else {
        'text'
    }

    switch ($format) {
        'json' {
            $jsonDepth = if ($ResultConfig -and ($ResultConfig.PSObject.Properties.Name -contains 'jsonDepth') -and $ResultConfig.jsonDepth) {
                [int]$ResultConfig.jsonDepth
            } else {
                10
            }

            if ($Result -is [string]) {
                $resultText = [string]$Result
                if ([string]::IsNullOrWhiteSpace($resultText)) {
                    return ''
                }

                try {
                    $parsedResult = $resultText | ConvertFrom-Json
                    return $parsedResult | ConvertTo-Json -Depth $jsonDepth
                }
                catch {
                    return $resultText
                }
            }

            return $Result | ConvertTo-Json -Depth $jsonDepth
        }

        default {
            return [string]$Result
        }
    }
}

function Resolve-PacToolRuntimePath {
    param(
        [AllowNull()]
        $PathValue,

        [AllowNull()]
        $ToolManifest
    )

    if ([string]::IsNullOrWhiteSpace([string]$PathValue)) {
        return $null
    }

    $candidatePath = [string]$PathValue
    if ([System.IO.Path]::IsPathRooted($candidatePath) -or -not $ToolManifest -or -not $ToolManifest.toolPath) {
        return $candidatePath
    }

    return [System.IO.Path]::GetFullPath((Join-Path -Path $ToolManifest.toolPath -ChildPath $candidatePath))
}

function Get-PacDefaultFileExtension {
    param(
        [Parameter(Mandatory)]
        $ParameterDefinition
    )

    if (($ParameterDefinition.PSObject.Properties.Name -contains 'resultOutput') -and $ParameterDefinition.resultOutput -and ($ParameterDefinition.resultOutput.PSObject.Properties.Name -contains 'defaultExtension') -and $ParameterDefinition.resultOutput.defaultExtension) {
        return [string]$ParameterDefinition.resultOutput.defaultExtension
    }

    if (($ParameterDefinition.PSObject.Properties.Name -contains 'pathPicker') -and $ParameterDefinition.pathPicker -and ($ParameterDefinition.pathPicker.PSObject.Properties.Name -contains 'defaultExtension') -and $ParameterDefinition.pathPicker.defaultExtension) {
        return [string]$ParameterDefinition.pathPicker.defaultExtension
    }

    return ''
}

function Add-PacDefaultFileExtension {
    param(
        [AllowNull()]
        [string]$PathValue,

        [AllowNull()]
        [string]$DefaultExtension
    )

    if ([string]::IsNullOrWhiteSpace($PathValue) -or [string]::IsNullOrWhiteSpace($DefaultExtension)) {
        return $PathValue
    }

    if (-not [string]::IsNullOrWhiteSpace([System.IO.Path]::GetExtension($PathValue))) {
        return $PathValue
    }

    $normalizedExtension = if ($DefaultExtension.StartsWith('.')) { $DefaultExtension } else { ".{0}" -f $DefaultExtension }
    return "{0}{1}" -f $PathValue, $normalizedExtension
}

function Get-PacEffectivePathValue {
    param(
        [Parameter(Mandatory)]
        $ParameterDefinition,

        [Parameter(Mandatory)]
        [string]$ParameterType,

        [AllowNull()]
        $Value
    )

    $stringValue = [string]$Value
    if ($ParameterType -ne 'File') {
        return $stringValue
    }

    $pickerConfig = if (($ParameterDefinition.PSObject.Properties.Name -contains 'pathPicker') -and $ParameterDefinition.pathPicker) {
        $ParameterDefinition.pathPicker
    } else {
        $null
    }
    $pickerMode = if ($pickerConfig -and ($pickerConfig.PSObject.Properties.Name -contains 'mode') -and $pickerConfig.mode) {
        [string]$pickerConfig.mode
    } else {
        'open'
    }
    $defaultExtension = Get-PacDefaultFileExtension -ParameterDefinition $ParameterDefinition
    $resultOutputConfig = if (($ParameterDefinition.PSObject.Properties.Name -contains 'resultOutput') -and $ParameterDefinition.resultOutput) {
        $ParameterDefinition.resultOutput
    } else {
        $null
    }
    $canAppendDefaultExtension = $null -ne $resultOutputConfig -or $pickerMode -eq 'save'
    $appendDefaultExtension = if ($resultOutputConfig -and ($resultOutputConfig.PSObject.Properties.Name -contains 'appendDefaultExtension')) {
        [bool]$resultOutputConfig.appendDefaultExtension
    } else {
        $canAppendDefaultExtension -and -not [string]::IsNullOrWhiteSpace($defaultExtension)
    }

    if (-not $appendDefaultExtension) {
        return $stringValue
    }

    return Add-PacDefaultFileExtension -PathValue $stringValue -DefaultExtension $defaultExtension
}

function Get-PacResultOutputBinding {
    param(
        [Parameter(Mandatory)]
        $ParameterDefinition,

        [AllowNull()]
        $Value,

        [AllowNull()]
        $ToolManifest
    )

    if (-not ($ParameterDefinition.PSObject.Properties.Name -contains 'resultOutput') -or -not $ParameterDefinition.resultOutput) {
        return $null
    }

    $resolvedPath = Resolve-PacToolRuntimePath -PathValue $Value -ToolManifest $ToolManifest
    if ([string]::IsNullOrWhiteSpace([string]$resolvedPath)) {
        return $null
    }

    $resultOutputConfig = $ParameterDefinition.resultOutput
    $defaultExtension = Get-PacDefaultFileExtension -ParameterDefinition $ParameterDefinition
    $appendDefaultExtension = if ($resultOutputConfig.PSObject.Properties.Name -contains 'appendDefaultExtension') {
        [bool]$resultOutputConfig.appendDefaultExtension
    } else {
        -not [string]::IsNullOrWhiteSpace($defaultExtension)
    }

    $effectiveValue = Get-PacEffectivePathValue -ParameterDefinition $ParameterDefinition -ParameterType 'File' -Value $Value

    $resolvedPath = Resolve-PacToolRuntimePath -PathValue $effectiveValue -ToolManifest $ToolManifest
    if ([string]::IsNullOrWhiteSpace([string]$resolvedPath)) {
        return $null
    }

    $contentMode = if (($resultOutputConfig.PSObject.Properties.Name -contains 'content') -and $resultOutputConfig.content) {
        [string]$resultOutputConfig.content
    } else {
        'formatted'
    }

    $overwriteExisting = if ($resultOutputConfig.PSObject.Properties.Name -contains 'overwriteExisting') {
        [bool]$resultOutputConfig.overwriteExisting
    } else {
        $true
    }

    $createParentDirectories = if ($resultOutputConfig.PSObject.Properties.Name -contains 'createParentDirectories') {
        [bool]$resultOutputConfig.createParentDirectories
    } else {
        $true
    }

    $confirmOverwrite = if ($resultOutputConfig.PSObject.Properties.Name -contains 'confirmOverwrite') {
        [bool]$resultOutputConfig.confirmOverwrite
    } else {
        $false
    }

    $confirmOverwriteTitle = if (($resultOutputConfig.PSObject.Properties.Name -contains 'confirmOverwriteTitle') -and $resultOutputConfig.confirmOverwriteTitle) {
        [string]$resultOutputConfig.confirmOverwriteTitle
    } else {
        'Overwrite Output File?'
    }

    $confirmOverwriteMessage = if (($resultOutputConfig.PSObject.Properties.Name -contains 'confirmOverwriteMessage') -and $resultOutputConfig.confirmOverwriteMessage) {
        [string]$resultOutputConfig.confirmOverwriteMessage
    } else {
        'The output file already exists:`r`n{outputPath}`r`n`r`nOverwrite it?'
    }

    return [pscustomobject]@{
        ParameterName           = [string]$ParameterDefinition.name
        Path                    = $resolvedPath
        OriginalValue           = [string]$Value
        EffectiveValue          = $effectiveValue
        DefaultExtension        = $defaultExtension
        AppendDefaultExtension  = $appendDefaultExtension
        Content                 = $contentMode
        OverwriteExisting       = $overwriteExisting
        CreateParentDirectories = $createParentDirectories
        ConfirmOverwrite        = $confirmOverwrite
        ConfirmOverwriteTitle   = $confirmOverwriteTitle
        ConfirmOverwriteMessage = $confirmOverwriteMessage
    }
}

function Test-PacParameterPassThrough {
    param(
        [Parameter(Mandatory)]
        $ParameterDefinition
    )

    if (($ParameterDefinition.PSObject.Properties.Name -contains 'resultOutput') -and $ParameterDefinition.resultOutput) {
        $resultOutputConfig = $ParameterDefinition.resultOutput
        if ($resultOutputConfig.PSObject.Properties.Name -contains 'passToScript') {
            return [bool]$resultOutputConfig.passToScript
        }

        return $false
    }

    return $true
}

function Save-PacToolResultOutput {
    param(
        [AllowNull()]
        $OutputBinding,

        [AllowNull()]
        $RawResult,

        [AllowNull()]
        [string]$FormattedResult,

        $Owner = $null
    )

    if ($null -eq $OutputBinding) {
        return [pscustomobject]@{
            Status = 'skipped'
            Path   = $null
            Reason = 'missingBinding'
        }
    }

    $content = switch ($OutputBinding.Content) {
        'raw' {
            if ($null -eq $RawResult) {
                $null
            } else {
                [string]$RawResult
            }
            break
        }
        default {
            $FormattedResult
            break
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$content)) {
        return [pscustomobject]@{
            Status = 'skipped'
            Path   = [string]$OutputBinding.Path
            Reason = 'noContent'
        }
    }

    if (Test-Path -LiteralPath $OutputBinding.Path) {
        $existingItem = Get-Item -LiteralPath $OutputBinding.Path
        if ($existingItem.PSIsContainer) {
            throw 'The output path points to an existing folder.'
        }

        if (-not $OutputBinding.OverwriteExisting) {
            throw 'The output file already exists.'
        }

        if ($OutputBinding.ConfirmOverwrite) {
            if (-not $Owner) {
                throw 'An overwrite confirmation requires a window owner.'
            }

            $confirmMessage = $OutputBinding.ConfirmOverwriteMessage.Replace('{outputPath}', [string]$OutputBinding.Path)
            $shouldOverwrite = Show-PacConfirmationDialog -Title $OutputBinding.ConfirmOverwriteTitle -Content $confirmMessage -Owner $Owner -PrimaryButtonText 'Overwrite' -CloseButtonText 'Cancel'
            if (-not $shouldOverwrite) {
                return [pscustomobject]@{
                    Status = 'skipped'
                    Path   = [string]$OutputBinding.Path
                    Reason = 'overwriteCanceled'
                }
            }
        }
    }

    $parentDirectory = Split-Path -Path $OutputBinding.Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($parentDirectory) -and -not (Test-Path -LiteralPath $parentDirectory)) {
        if (-not $OutputBinding.CreateParentDirectories) {
            throw 'The output file parent directory does not exist.'
        }

        [System.IO.Directory]::CreateDirectory($parentDirectory) | Out-Null
    }

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($OutputBinding.Path, $content, $utf8NoBom)

    return [pscustomobject]@{
        Status = 'saved'
        Path   = [string]$OutputBinding.Path
        Reason = $null
    }
}

function Get-PacSaveResultActionBinding {
    param(
        [Parameter(Mandatory)]
        $ActionConfig,

        [Parameter(Mandatory)]
        [string]$SelectedPath
    )

    $defaultExtension = Get-PacOptionalText -Source $ActionConfig -PropertyName 'defaultExtension'
    $appendDefaultExtension = if (($ActionConfig.PSObject.Properties.Name -contains 'appendDefaultExtension')) {
        [bool]$ActionConfig.appendDefaultExtension
    } else {
        -not [string]::IsNullOrWhiteSpace($defaultExtension)
    }

    $effectivePath = if ($appendDefaultExtension) {
        Add-PacDefaultFileExtension -PathValue $SelectedPath -DefaultExtension $defaultExtension
    } else {
        $SelectedPath
    }

    return [pscustomobject]@{
        ParameterName           = 'saveResult'
        Path                    = $effectivePath
        OriginalValue           = $SelectedPath
        EffectiveValue          = $effectivePath
        DefaultExtension        = $defaultExtension
        AppendDefaultExtension  = $appendDefaultExtension
        Content                 = 'formatted'
        OverwriteExisting       = if (($ActionConfig.PSObject.Properties.Name -contains 'overwriteExisting')) { [bool]$ActionConfig.overwriteExisting } else { $true }
        CreateParentDirectories = if (($ActionConfig.PSObject.Properties.Name -contains 'createParentDirectories')) { [bool]$ActionConfig.createParentDirectories } else { $true }
        ConfirmOverwrite        = if (($ActionConfig.PSObject.Properties.Name -contains 'confirmOverwrite')) { [bool]$ActionConfig.confirmOverwrite } else { $false }
        ConfirmOverwriteTitle   = Get-PacCustomText -Source $ActionConfig -PropertyName 'confirmOverwriteTitle' -DefaultValue 'Overwrite Saved Result?'
        ConfirmOverwriteMessage = Get-PacCustomText -Source $ActionConfig -PropertyName 'confirmOverwriteMessage' -DefaultValue 'The selected save path already exists:`r`n{outputPath}`r`n`r`nOverwrite it?'
    }
}

function Get-PacPathValidationConfig {
    param(
        [Parameter(Mandatory)]
        $ParameterDefinition,

        [Parameter(Mandatory)]
        [string]$ParameterType
    )

    $pickerConfig = if (($ParameterDefinition.PSObject.Properties.Name -contains 'pathPicker') -and $ParameterDefinition.pathPicker) {
        $ParameterDefinition.pathPicker
    } else {
        $null
    }

    $pathValidation = if (($ParameterDefinition.PSObject.Properties.Name -contains 'pathValidation') -and $ParameterDefinition.pathValidation) {
        $ParameterDefinition.pathValidation
    } else {
        $null
    }

    $pickerMode = if ($pickerConfig -and ($pickerConfig.PSObject.Properties.Name -contains 'mode') -and $pickerConfig.mode) {
        [string]$pickerConfig.mode
    } else {
        'open'
    }

    switch ($ParameterType) {
        'Folder' {
            $mustExist = if ($pathValidation -and ($pathValidation.PSObject.Properties.Name -contains 'mustExist')) {
                [bool]$pathValidation.mustExist
            } elseif ($pickerConfig -and ($pickerConfig.PSObject.Properties.Name -contains 'showNewFolderButton')) {
                -not [bool]$pickerConfig.showNewFolderButton
            } else {
                $true
            }

            $parentMustExist = if ($pathValidation -and ($pathValidation.PSObject.Properties.Name -contains 'parentMustExist')) {
                [bool]$pathValidation.parentMustExist
            } else {
                $false
            }

            return [pscustomobject]@{
                MustExist       = $mustExist
                ParentMustExist = $parentMustExist
                ExpectedType    = 'Folder'
            }
        }

        'File' {
            $resultOutputConfig = if (($ParameterDefinition.PSObject.Properties.Name -contains 'resultOutput') -and $ParameterDefinition.resultOutput) {
                $ParameterDefinition.resultOutput
            } else {
                $null
            }

            $mustExist = if ($pathValidation -and ($pathValidation.PSObject.Properties.Name -contains 'mustExist')) {
                [bool]$pathValidation.mustExist
            } elseif ($pickerMode -eq 'save') {
                $false
            } elseif ($pickerConfig -and ($pickerConfig.PSObject.Properties.Name -contains 'checkFileExists')) {
                [bool]$pickerConfig.checkFileExists
            } else {
                $true
            }

            $parentMustExist = if ($pathValidation -and ($pathValidation.PSObject.Properties.Name -contains 'parentMustExist')) {
                [bool]$pathValidation.parentMustExist
            } elseif (($ParameterDefinition.PSObject.Properties.Name -contains 'resultOutput') -and $ParameterDefinition.resultOutput) {
                if ($resultOutputConfig -and ($resultOutputConfig.PSObject.Properties.Name -contains 'createParentDirectories')) {
                    -not [bool]$resultOutputConfig.createParentDirectories
                } else {
                    $false
                }
            } else {
                $pickerMode -eq 'save'
            }

            $mustNotExist = if ($pathValidation -and ($pathValidation.PSObject.Properties.Name -contains 'mustNotExist')) {
                [bool]$pathValidation.mustNotExist
            } elseif ($resultOutputConfig -and ($resultOutputConfig.PSObject.Properties.Name -contains 'overwriteExisting')) {
                -not [bool]$resultOutputConfig.overwriteExisting
            } else {
                $false
            }

            return [pscustomobject]@{
                MustExist       = $mustExist
                MustNotExist    = $mustNotExist
                ParentMustExist = $parentMustExist
                ExpectedType    = 'File'
            }
        }
    }

    return $null
}

function Test-PacPathConstraint {
    param(
        [Parameter(Mandatory)]
        $ParameterDefinition,

        [Parameter(Mandatory)]
        [string]$ParameterType,

        [Parameter(Mandatory)]
        [string]$Label,

        [AllowNull()]
        $Value,

        [AllowNull()]
        $ToolManifest
    )

    $pathConfig = Get-PacPathValidationConfig -ParameterDefinition $ParameterDefinition -ParameterType $ParameterType
    if ($null -eq $pathConfig) {
        return [pscustomobject]@{
            IsValid = $true
            Message = $null
        }
    }

    $effectiveValue = Get-PacEffectivePathValue -ParameterDefinition $ParameterDefinition -ParameterType $ParameterType -Value $Value
    $resolvedPath = Resolve-PacToolRuntimePath -PathValue $effectiveValue -ToolManifest $ToolManifest

    if ($ParameterType -eq 'File') {
        $defaultExtension = Get-PacDefaultFileExtension -ParameterDefinition $ParameterDefinition
        $pathValidation = if (($ParameterDefinition.PSObject.Properties.Name -contains 'pathValidation') -and $ParameterDefinition.pathValidation) {
            $ParameterDefinition.pathValidation
        } else {
            $null
        }
        $resultOutputConfig = if (($ParameterDefinition.PSObject.Properties.Name -contains 'resultOutput') -and $ParameterDefinition.resultOutput) {
            $ParameterDefinition.resultOutput
        } else {
            $null
        }
        $enforceDefaultExtension = if ($resultOutputConfig -and ($resultOutputConfig.PSObject.Properties.Name -contains 'enforceDefaultExtension')) {
            [bool]$resultOutputConfig.enforceDefaultExtension
        } elseif ($pathValidation -and ($pathValidation.PSObject.Properties.Name -contains 'enforceDefaultExtension')) {
            [bool]$pathValidation.enforceDefaultExtension
        } else {
            $false
        }

        if ($enforceDefaultExtension -and -not [string]::IsNullOrWhiteSpace($defaultExtension)) {
            $providedExtension = [System.IO.Path]::GetExtension([string]$Value)
            if (-not [string]::IsNullOrWhiteSpace($providedExtension)) {
                $normalizedExpectedExtension = if ($defaultExtension.StartsWith('.')) { $defaultExtension } else { ".{0}" -f $defaultExtension }
                if ($providedExtension -ine $normalizedExpectedExtension) {
                    return [pscustomobject]@{
                        IsValid = $false
                        Message = Get-PacValidationMessage -ParameterDefinition $ParameterDefinition -Rule 'invalidFileExtension' -DefaultMessage "$Label must use the $normalizedExpectedExtension extension."
                    }
                }
            }
        }
    }

    try {
        $pathExists = Test-Path -LiteralPath $resolvedPath
    }
    catch {
        $pathExists = $false
        $invalidRule = if ($ParameterType -eq 'Folder') { 'invalidFolderPath' } else { 'invalidFilePath' }
        $invalidMessage = if ($ParameterType -eq 'Folder') {
            "$Label must be a valid folder path."
        } else {
            "$Label must be a valid file path."
        }

        return [pscustomobject]@{
            IsValid = $false
            Message = Get-PacValidationMessage -ParameterDefinition $ParameterDefinition -Rule $invalidRule -DefaultMessage $invalidMessage
        }
    }

    if ($pathExists) {
        $item = Get-Item -LiteralPath $resolvedPath -ErrorAction SilentlyContinue
        if ($null -eq $item) {
            $pathExists = $false
        } elseif ($ParameterType -eq 'Folder' -and -not $item.PSIsContainer) {
            return [pscustomobject]@{
                IsValid = $false
                Message = Get-PacValidationMessage -ParameterDefinition $ParameterDefinition -Rule 'invalidFolderPath' -DefaultMessage "$Label must be a folder path."
            }
        } elseif ($ParameterType -eq 'File' -and $item.PSIsContainer) {
            return [pscustomobject]@{
                IsValid = $false
                Message = Get-PacValidationMessage -ParameterDefinition $ParameterDefinition -Rule 'invalidFilePath' -DefaultMessage "$Label must be a file path."
            }
        }
    }

    if ($pathExists -and ($pathConfig.PSObject.Properties.Name -contains 'MustNotExist') -and $pathConfig.MustNotExist) {
        return [pscustomobject]@{
            IsValid = $false
            Message = Get-PacValidationMessage -ParameterDefinition $ParameterDefinition -Rule 'fileAlreadyExists' -DefaultMessage "$Label already exists. Choose a different file path."
        }
    }

    if ($pathExists) {
        return [pscustomobject]@{
            IsValid = $true
            Message = $null
        }
    }

    if ($pathConfig.MustExist) {
        $missingRule = if ($ParameterType -eq 'Folder') { 'folderNotFound' } else { 'fileNotFound' }
        $missingMessage = if ($ParameterType -eq 'Folder') {
            "Select an existing folder for $Label."
        } else {
            "Select an existing file for $Label."
        }

        return [pscustomobject]@{
            IsValid = $false
            Message = Get-PacValidationMessage -ParameterDefinition $ParameterDefinition -Rule $missingRule -DefaultMessage $missingMessage
        }
    }

    if ($pathConfig.ParentMustExist) {
        $parentPath = Split-Path -Path $resolvedPath -Parent
        if ([string]::IsNullOrWhiteSpace($parentPath) -or -not (Test-Path -LiteralPath $parentPath -PathType Container)) {
            return [pscustomobject]@{
                IsValid = $false
                Message = Get-PacValidationMessage -ParameterDefinition $ParameterDefinition -Rule 'parentDirectoryNotFound' -DefaultMessage "The parent directory for $Label must exist."
            }
        }
    }

    return [pscustomobject]@{
        IsValid = $true
        Message = $null
    }
}

function Test-PacParameterConstraint {
    param(
        [Parameter(Mandatory)]
        $ParameterDefinition,

        [AllowNull()]
        $Value,

        [string]$ParameterType = 'String',

        [AllowNull()]
        $ToolManifest
    )

    $label = if ($ParameterDefinition.label) { $ParameterDefinition.label } else { $ParameterDefinition.name }

    if (-not (Test-PacToolValuePresent -Value $Value -ParameterType $ParameterType)) {
        return [pscustomobject]@{
            IsValid = $true
            Message = $null
        }
    }

    if (($ParameterDefinition.PSObject.Properties.Name -contains 'allowedValues') -and $ParameterDefinition.allowedValues) {
        if (-not (Test-PacAllowedValue -Value $Value -AllowedValues $ParameterDefinition.allowedValues)) {
            $allowedValueList = (@($ParameterDefinition.allowedValues) | ForEach-Object { [string]$_ }) -join ', '
            return [pscustomobject]@{
                IsValid = $false
                Message = Get-PacValidationMessage -ParameterDefinition $ParameterDefinition -Rule 'allowedValues' -DefaultMessage "$label must be one of: $allowedValueList."
            }
        }
    }

    if ($ParameterType -in @('File', 'Folder')) {
        return Test-PacPathConstraint -ParameterDefinition $ParameterDefinition -ParameterType $ParameterType -Label $label -Value $Value -ToolManifest $ToolManifest
    }

    if ($ParameterType -eq 'Number') {
        if (($ParameterDefinition.PSObject.Properties.Name -contains 'integerOnly') -and [bool]$ParameterDefinition.integerOnly) {
            $numberValue = [double]$Value
            if ($numberValue -ne [math]::Truncate($numberValue)) {
                return [pscustomobject]@{
                    IsValid = $false
                    Message = Get-PacValidationMessage -ParameterDefinition $ParameterDefinition -Rule 'integer' -DefaultMessage "$label must be a whole number."
                }
            }
        }

        if (($ParameterDefinition.PSObject.Properties.Name -contains 'min') -and $null -ne $ParameterDefinition.min -and $Value -lt $ParameterDefinition.min) {
            return [pscustomobject]@{
                IsValid = $false
                Message = Get-PacValidationMessage -ParameterDefinition $ParameterDefinition -Rule 'min' -DefaultMessage "$label must be greater than or equal to $($ParameterDefinition.min)."
            }
        }

        if (($ParameterDefinition.PSObject.Properties.Name -contains 'max') -and $null -ne $ParameterDefinition.max -and $Value -gt $ParameterDefinition.max) {
            return [pscustomobject]@{
                IsValid = $false
                Message = Get-PacValidationMessage -ParameterDefinition $ParameterDefinition -Rule 'max' -DefaultMessage "$label must be less than or equal to $($ParameterDefinition.max)."
            }
        }
    }

    if ($ParameterType -eq 'String') {
        $stringValue = [string]$Value

        if (($ParameterDefinition.PSObject.Properties.Name -contains 'minLength') -and $null -ne $ParameterDefinition.minLength -and $stringValue.Length -lt [int]$ParameterDefinition.minLength) {
            return [pscustomobject]@{
                IsValid = $false
                Message = Get-PacValidationMessage -ParameterDefinition $ParameterDefinition -Rule 'minLength' -DefaultMessage "$label must be at least $($ParameterDefinition.minLength) characters long."
            }
        }

        if (($ParameterDefinition.PSObject.Properties.Name -contains 'maxLength') -and $null -ne $ParameterDefinition.maxLength -and $stringValue.Length -gt [int]$ParameterDefinition.maxLength) {
            return [pscustomobject]@{
                IsValid = $false
                Message = Get-PacValidationMessage -ParameterDefinition $ParameterDefinition -Rule 'maxLength' -DefaultMessage "$label must be no more than $($ParameterDefinition.maxLength) characters long."
            }
        }
    }

    return [pscustomobject]@{
        IsValid = $true
        Message = $null
    }
}

function Show-PacParameterValidationDialog {
    param(
        [AllowNull()]
        $DialogConfig,

        [Parameter(Mandatory)]
        [string]$ErrorKind,

        [Parameter(Mandatory)]
        [string]$Message,

        $Owner = $null
    )

    switch ($ErrorKind) {
        'required' {
            $title = Get-PacToolDialogText -DialogConfig $DialogConfig -PropertyName 'missingInputTitle' -DefaultValue 'Missing Input'
            $dialogMessage = Get-PacToolDialogText -DialogConfig $DialogConfig -PropertyName 'missingInputMessage' -DefaultValue $Message
        }
        'invalidNumber' {
            $title = Get-PacToolDialogText -DialogConfig $DialogConfig -PropertyName 'invalidNumberTitle' -DefaultValue 'Invalid Number'
            $dialogMessage = Get-PacToolDialogText -DialogConfig $DialogConfig -PropertyName 'invalidNumberMessage' -DefaultValue $Message
        }
        default {
            $title = Get-PacToolDialogText -DialogConfig $DialogConfig -PropertyName 'invalidValueTitle' -DefaultValue 'Invalid Value'
            $dialogMessage = Get-PacToolDialogText -DialogConfig $DialogConfig -PropertyName 'invalidValueMessage' -DefaultValue $Message
        }
    }

    Show-PacDialog -Title $title -Content $dialogMessage -Owner $Owner
}

function Resolve-PacParameterProcessing {
    param(
        [Parameter(Mandatory)]
        $ParameterDefinition,

        [AllowNull()]
        $Control,

        [AllowNull()]
        $ToolManifest
    )

    $parameterType = if (($ParameterDefinition.PSObject.Properties.Name -contains 'type') -and $ParameterDefinition.type) {
        [string]$ParameterDefinition.type
    } else {
        'String'
    }
    $label = if ($ParameterDefinition.label) { $ParameterDefinition.label } else { $ParameterDefinition.name }
    $passToScript = Test-PacParameterPassThrough -ParameterDefinition $ParameterDefinition

    switch ($parameterType) {
        'Boolean' {
            $value = [bool]$Control.IsChecked
            $validation = Test-PacParameterConstraint -ParameterDefinition $ParameterDefinition -Value $value -ParameterType $parameterType -ToolManifest $ToolManifest
            if (-not $validation.IsValid) {
                return [pscustomobject]@{
                    IsValid     = $false
                    ErrorKind   = 'invalidValue'
                    ErrorMessage = $validation.Message
                }
            }

            return [pscustomobject]@{
                IsValid           = $true
                SavedValue        = $value
                IncludeInScript   = ($value -and $passToScript)
                ScriptValue       = $true
                ResultOutputBinding = $null
                UpdatedControlValue = $null
            }
        }

        'Number' {
            $rawValue = [string]$Control.Text
            if ($ParameterDefinition.required -and [string]::IsNullOrWhiteSpace($rawValue)) {
                return [pscustomobject]@{
                    IsValid      = $false
                    ErrorKind    = 'required'
                    ErrorMessage = Get-PacValidationMessage -ParameterDefinition $ParameterDefinition -Rule 'required' -DefaultMessage "Please enter $label."
                }
            }

            if ([string]::IsNullOrWhiteSpace($rawValue)) {
                return [pscustomobject]@{
                    IsValid             = $true
                    SavedValue          = ''
                    IncludeInScript     = $false
                    ScriptValue         = $null
                    ResultOutputBinding = $null
                    UpdatedControlValue = $null
                }
            }

            try {
                $value = ConvertFrom-PacNumberInput -Value $rawValue
            }
            catch {
                return [pscustomobject]@{
                    IsValid      = $false
                    ErrorKind    = 'invalidNumber'
                    ErrorMessage = Get-PacValidationMessage -ParameterDefinition $ParameterDefinition -Rule 'invalidNumber' -DefaultMessage "$label must be a valid number."
                }
            }

            $validation = Test-PacParameterConstraint -ParameterDefinition $ParameterDefinition -Value $value -ParameterType $parameterType -ToolManifest $ToolManifest
            if (-not $validation.IsValid) {
                return [pscustomobject]@{
                    IsValid      = $false
                    ErrorKind    = 'invalidValue'
                    ErrorMessage = $validation.Message
                }
            }

            $resultOutputBinding = Get-PacResultOutputBinding -ParameterDefinition $ParameterDefinition -Value $value -ToolManifest $ToolManifest
            $updatedControlValue = $null
            $savedValue = $value
            if ($resultOutputBinding -and $resultOutputBinding.EffectiveValue -and ($resultOutputBinding.EffectiveValue -ne $rawValue)) {
                $updatedControlValue = [string]$resultOutputBinding.EffectiveValue
                $savedValue = $updatedControlValue
            }

            return [pscustomobject]@{
                IsValid             = $true
                SavedValue          = $savedValue
                IncludeInScript     = $passToScript
                ScriptValue         = $value
                ResultOutputBinding = $resultOutputBinding
                UpdatedControlValue = $updatedControlValue
            }
        }

        default {
            if (Test-PacControlIsComboBox -Control $Control) {
                $value = if ($null -ne $Control.SelectedItem) { [string]$Control.SelectedItem } else { '' }
            } else {
                $value = [string]$Control.Text
            }

            if ($ParameterDefinition.required -and [string]::IsNullOrWhiteSpace([string]$value)) {
                return [pscustomobject]@{
                    IsValid      = $false
                    ErrorKind    = 'required'
                    ErrorMessage = Get-PacValidationMessage -ParameterDefinition $ParameterDefinition -Rule 'required' -DefaultMessage "Please enter $label."
                }
            }

            $validation = Test-PacParameterConstraint -ParameterDefinition $ParameterDefinition -Value $value -ParameterType $parameterType -ToolManifest $ToolManifest
            if (-not $validation.IsValid) {
                return [pscustomobject]@{
                    IsValid      = $false
                    ErrorKind    = 'invalidValue'
                    ErrorMessage = $validation.Message
                }
            }

            $resultOutputBinding = Get-PacResultOutputBinding -ParameterDefinition $ParameterDefinition -Value $value -ToolManifest $ToolManifest
            $updatedControlValue = $null
            $savedValue = $value
            if ($resultOutputBinding -and $resultOutputBinding.EffectiveValue -and ($resultOutputBinding.EffectiveValue -ne [string]$value)) {
                $updatedControlValue = [string]$resultOutputBinding.EffectiveValue
                $savedValue = $updatedControlValue
            }

            return [pscustomobject]@{
                IsValid             = $true
                SavedValue          = $savedValue
                IncludeInScript     = $passToScript -and -not [string]::IsNullOrWhiteSpace([string]$value)
                ScriptValue         = $value
                ResultOutputBinding = $resultOutputBinding
                UpdatedControlValue = $updatedControlValue
            }
        }
    }
}

function Resolve-PacInitialParameterValue {
    param(
        [Parameter(Mandatory)]
        $ParameterDefinition,

        [AllowNull()]
        $ToolConfig
    )

    $parameterType = if (($ParameterDefinition.PSObject.Properties.Name -contains 'type') -and $ParameterDefinition.type) {
        [string]$ParameterDefinition.type
    } else {
        'String'
    }

    $savedValue = $null
    $defaultValue = $null
    $hasSavedEntry = $false
    $hasDefaultValue = $false

    if ($ToolConfig -and ($ToolConfig.PSObject.Properties.Name -contains 'savedValues') -and $ToolConfig.savedValues) {
        $savedValue = Get-PacToolConfigValue -Values $ToolConfig.savedValues -ParameterName $ParameterDefinition.name
        $hasSavedEntry = Test-PacToolConfigHasEntry -Values $ToolConfig.savedValues -ParameterName $ParameterDefinition.name
    }

    if ($ToolConfig -and ($ToolConfig.PSObject.Properties.Name -contains 'defaults') -and $ToolConfig.defaults) {
        $defaultValue = Get-PacToolConfigValue -Values $ToolConfig.defaults -ParameterName $ParameterDefinition.name
        $hasDefaultValue = Test-PacToolValuePresent -Value $defaultValue -ParameterType $parameterType
    }

    if (($ParameterDefinition.PSObject.Properties.Name -contains 'allowedValues') -and $ParameterDefinition.allowedValues) {
        if ($hasSavedEntry -and -not [string]::IsNullOrWhiteSpace([string]$savedValue) -and -not (Test-PacAllowedValue -Value $savedValue -AllowedValues $ParameterDefinition.allowedValues)) {
            $hasSavedEntry = $false
            $savedValue = $null
        }

        if ($hasDefaultValue -and -not (Test-PacAllowedValue -Value $defaultValue -AllowedValues $ParameterDefinition.allowedValues)) {
            $hasDefaultValue = $false
            $defaultValue = $null
        }
    }

    $fieldValue = if ($hasSavedEntry) { $savedValue } elseif ($hasDefaultValue) { $defaultValue } else { $null }
    if ($parameterType -in @('File', 'Folder') -and -not [string]::IsNullOrWhiteSpace([string]$fieldValue)) {
        $fieldValue = Get-PacEffectivePathValue -ParameterDefinition $ParameterDefinition -ParameterType $parameterType -Value $fieldValue
    }

    return $fieldValue
}

function Show-PacSimpleToolWindow {
    param(
        [Parameter(Mandatory)]
        $ToolManifest
    )

    $resources = [Application]::Current.Resources
    $toolConfig = Get-PacToolConfig -ConfigPath $ToolManifest.configPath

    $windowTitle = if ($ToolManifest.window.title) { $ToolManifest.window.title } else { $ToolManifest.name }
    $windowSubtitle = if (($ToolManifest.PSObject.Properties.Name -contains 'category') -and $ToolManifest.category) { [string]$ToolManifest.category } else { '' }
    $windowWidth = if ($ToolManifest.window.width) { [int]$ToolManifest.window.width } else { 600 }
    $windowHeight = if ($ToolManifest.window.height) { [int]$ToolManifest.window.height } else { 420 }

    $childWin = New-PacChildWindow -Title $windowTitle -Subtitle $windowSubtitle -Width $windowWidth -Height $windowHeight -CenterOnPointerScreen

    $root = [StackPanel]::new()
    $root.Margin = 24
    $root.Spacing = 16

    $inputControls = @{}
    foreach ($parameter in @($ToolManifest.parameters)) {
        $fieldValue = Resolve-PacInitialParameterValue -ParameterDefinition $parameter -ToolConfig $toolConfig
        $field = New-PacToolTextInput -Resources $resources -ParameterDefinition $parameter -Value $fieldValue -Owner $childWin -ToolManifest $ToolManifest

        $inputControls[$parameter.name] = $field.Input
        $root.Children.Add($field.Container)
    }

    $uiConfig = if ($ToolManifest.PSObject.Properties.Name -contains 'ui') { $ToolManifest.ui } else { $null }
    $dialogConfig = if ($uiConfig -and ($uiConfig.PSObject.Properties.Name -contains 'dialogs')) { $uiConfig.dialogs } else { $null }
    $resultConfig = if ($uiConfig -and ($uiConfig.PSObject.Properties.Name -contains 'result')) { $uiConfig.result } else { $null }
    $actionConfigs = if ($uiConfig -and ($uiConfig.PSObject.Properties.Name -contains 'actions')) { @($uiConfig.actions) } else { @() }
    $hasResultOutputParameters = @($ToolManifest.parameters | Where-Object { ($_.PSObject.Properties.Name -contains 'resultOutput') -and $_.resultOutput }).Count -gt 0

    $resultBox = $null
    $statusBlock = $null
    if ($resultConfig -or $actionConfigs.Count -gt 0) {
        $resultLabel = [TextBlock]::new()
        $resultLabel.Text = if ($resultConfig -and $resultConfig.label) { $resultConfig.label } else { 'Result' }
        $resultLabel.Style = $resources['BodyTextBlockStyle']

        $resultBox = [TextBox]::new()
        $resultBox.IsReadOnly = $true
        $resultBox.TextWrapping = 'Wrap'
        $resultBox.AcceptsReturn = $true
        $resultBox.MinHeight = if ($resultConfig -and $resultConfig.minHeight) { [double]$resultConfig.minHeight } else { 72 }
        $resultBox.PlaceHolderText = if ($resultConfig -and $resultConfig.placeholder) { $resultConfig.placeholder } else { 'Tool output will appear here.' }

        $root.Children.Add($resultLabel)
        $root.Children.Add($resultBox)

        if ($hasResultOutputParameters) {
            $statusBlock = [TextBlock]::new()
            $statusBlock.TextWrapping = 'Wrap'
            $statusBlock.Style = $resources['BodyTextBlockStyle']
            $statusBlock.Opacity = 0.85
            $statusBlock.Text = ''
            $root.Children.Add($statusBlock)
        }
    }

    $primaryButton = [Button]::new()
    $primaryButton.Content = if ($uiConfig -and $uiConfig.primaryActionText) { $uiConfig.primaryActionText } else { 'Run Tool' }
    $primaryButton.Style = $resources['AccentButtonStyle']

    $requiresNetwork = ($ToolManifest.PSObject.Properties.Name -contains 'requiresNetwork') -and [bool]$ToolManifest.requiresNetwork
    $offlineMessage = if (($ToolManifest.PSObject.Properties.Name -contains 'offlineMessage') -and $ToolManifest.offlineMessage) {
        $ToolManifest.offlineMessage
    } else {
        'This tool is unavailable because a network connection is required.'
    }

    if ($requiresNetwork -and -not (Test-PacNetworkAvailability)) {
        $primaryButton.IsEnabled = $false

        $offlineNotice = [TextBlock]::new()
        $offlineNotice.Text = $offlineMessage
        $offlineNotice.TextWrapping = 'Wrap'
        $offlineNotice.Style = $resources['BodyTextBlockStyle']
        $root.Children.Add($offlineNotice)
    }

    $root.Children.Add($primaryButton)

    $actionButtons = [System.Collections.ArrayList]::new()
    $actionStates = [System.Collections.ArrayList]::new()
    if ($actionConfigs.Count -gt 0) {
        $actionPanel = [StackPanel]::new()
        $actionPanel.Orientation = 'Horizontal'
        $actionPanel.Spacing = 12

        foreach ($actionConfig in $actionConfigs) {
            $actionButton = [Button]::new()
            $actionButton.Content = if ($actionConfig.label) { $actionConfig.label } else { $actionConfig.kind }
            $actionButton.IsEnabled = $false

            $actionState = @{
                ActionConfig = $actionConfig
                ResultBox    = $resultBox
                CurrentResultText = ''
                Owner        = $childWin
                ToolManifest = $ToolManifest
                OutputFiles  = @{}
            }

            $actionCallback = [EventCallback]::new()
            $actionCallback.ArgumentList = $actionState
            $actionCallback.ScriptBlock = {
                param($state, $sender, $e)

                $resultText = if ($state.ContainsKey('CurrentResultText')) { [string]$state.CurrentResultText } elseif ($state.ResultBox) { [string]$state.ResultBox.Text } else { '' }
                $outputPath = Get-PacActionOutputPath -ActionConfig $state.ActionConfig -OutputFiles $state.OutputFiles
                if (-not (Test-PacActionHasTarget -ActionConfig $state.ActionConfig -ResultText $resultText -OutputFiles $state.OutputFiles)) {
                    $noResultTitle = Get-PacCustomText -Source $state.ActionConfig -PropertyName 'noResultTitle' -DefaultValue 'No Result'
                    $noResultMessage = Get-PacCustomText -Source $state.ActionConfig -PropertyName 'noResultMessage' -DefaultValue 'Run the tool before using this action.'
                    Show-PacDialog -Title $noResultTitle -Content $noResultMessage -Owner $state.Owner
                    return
                }

                try {
                    switch ($state.ActionConfig.kind) {
                        'copyResult' {
                            Set-Clipboard -Value $resultText
                            $successTitle = Get-PacCustomText -Source $state.ActionConfig -PropertyName 'successTitle' -DefaultValue 'Copied'
                            $successMessage = Get-PacCustomText -Source $state.ActionConfig -PropertyName 'successMessage' -DefaultValue 'The result has been copied to the clipboard.'
                            Show-PacDialog -Title $successTitle -Content $successMessage -Owner $state.Owner
                        }
                        'saveResult' {
                            Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue

                            $confirmOverwrite = if (($state.ActionConfig.PSObject.Properties.Name -contains 'confirmOverwrite')) {
                                [bool]$state.ActionConfig.confirmOverwrite
                            } else {
                                $false
                            }

                            $dialog = [System.Windows.Forms.SaveFileDialog]::new()
                            $dialog.Filter = Get-PacCustomText -Source $state.ActionConfig -PropertyName 'filter' -DefaultValue 'Text files (*.txt)|*.txt|All files (*.*)|*.*'
                            $dialog.Title = Get-PacCustomText -Source $state.ActionConfig -PropertyName 'title' -DefaultValue 'Save Result'

                            $defaultExtension = Get-PacOptionalText -Source $state.ActionConfig -PropertyName 'defaultExtension'
                            if ($defaultExtension) {
                                $dialog.DefaultExt = $defaultExtension
                                $dialog.AddExtension = $true
                            }
                            $dialog.OverwritePrompt = -not $confirmOverwrite

                            $defaultFileName = Get-PacOptionalText -Source $state.ActionConfig -PropertyName 'fileName'
                            if ($defaultFileName) {
                                $dialog.FileName = $defaultFileName
                            }

                            $initialDirectory = Resolve-PacActionDirectory -ActionConfig $state.ActionConfig -ToolManifest $state.ToolManifest -ResultText $resultText
                            if ($initialDirectory) {
                                $dialog.InitialDirectory = $initialDirectory
                            }

                            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                                $saveBinding = Get-PacSaveResultActionBinding -ActionConfig $state.ActionConfig -SelectedPath $dialog.FileName
                                $saveOutcome = Save-PacToolResultOutput -OutputBinding $saveBinding -RawResult $resultText -FormattedResult $resultText -Owner $state.Owner

                                if ($saveOutcome.Status -eq 'saved') {
                                    $successTitle = Get-PacCustomText -Source $state.ActionConfig -PropertyName 'successTitle' -DefaultValue 'Saved'
                                    $successMessage = Get-PacCustomText -Source $state.ActionConfig -PropertyName 'successMessage' -DefaultValue "Saved the result to $($saveOutcome.Path)."
                                    Show-PacDialog -Title $successTitle -Content $successMessage -Owner $state.Owner
                                } elseif ($saveOutcome.Status -eq 'skipped') {
                                    $skippedTitle = Get-PacCustomText -Source $state.ActionConfig -PropertyName 'skippedTitle' -DefaultValue 'Save Skipped'
                                    $defaultSkippedMessage = if ($saveOutcome.Reason -eq 'overwriteCanceled') {
                                        'The result was not saved because overwrite was canceled.'
                                    } else {
                                        'The result was not saved.'
                                    }
                                    $skippedMessage = Get-PacCustomText -Source $state.ActionConfig -PropertyName 'skippedMessage' -DefaultValue $defaultSkippedMessage
                                    Show-PacDialog -Title $skippedTitle -Content $skippedMessage -Owner $state.Owner
                                }
                            }
                        }
                        'openResult' {
                            $openTarget = Resolve-PacOpenResultTarget -ResultText $resultText
                            if ($openTarget.Kind -eq 'missingPath') {
                                throw 'The result path does not exist.'
                            }
                            if ($openTarget.Kind -ne 'path' -and $openTarget.Kind -ne 'uri') {
                                throw 'The result is not an openable file path or URL.'
                            }

                            Start-Process $openTarget.Target
                        }
                        'openContainingFolder' {
                            $openTarget = Resolve-PacOpenResultTarget -ResultText $resultText
                            if ($openTarget.Kind -ne 'path') {
                                throw 'The result path does not exist.'
                            }

                            $item = Get-Item -LiteralPath $openTarget.Target
                            if ($item.PSIsContainer) {
                                Start-Process $item.FullName
                            } else {
                                Start-Process 'explorer.exe' "/select,$($item.FullName)"
                            }
                        }
                        'openOutput' {
                            $outputTarget = Resolve-PacOutputActionTarget -ActionConfig $state.ActionConfig -OutputFiles $state.OutputFiles
                            if ($outputTarget.Kind -ne 'path') {
                                throw 'The saved output path does not exist.'
                            }

                            Start-Process $outputTarget.Target
                        }
                        'openOutputContainingFolder' {
                            $outputTarget = Resolve-PacOutputActionTarget -ActionConfig $state.ActionConfig -OutputFiles $state.OutputFiles
                            if ($outputTarget.Kind -ne 'path') {
                                throw 'The saved output path does not exist.'
                            }

                            $item = Get-Item -LiteralPath $outputTarget.Target
                            if ($item.PSIsContainer) {
                                Start-Process $item.FullName
                            } else {
                                Start-Process 'explorer.exe' "/select,$($item.FullName)"
                            }
                        }
                        default {
                            throw "Unsupported action kind: $($state.ActionConfig.kind)"
                        }
                    }
                }
                catch {
                    $errorTitle = Get-PacCustomText -Source $state.ActionConfig -PropertyName 'errorTitle' -DefaultValue 'Action Error'
                    Show-PacDialog -Title $errorTitle -Content $_.Exception.Message -Owner $state.Owner
                }
            }

            $actionButton.AddClick($actionCallback)
            [void]$actionButtons.Add($actionButton)
            [void]$actionStates.Add($actionState)
            $actionPanel.Children.Add($actionButton)
        }

        $root.Children.Add($actionPanel)
    }

    $runState = @{
        InputControls   = $inputControls
        ResultBox       = $resultBox
        StatusBlock     = $statusBlock
        ResultConfig    = $resultConfig
        DialogConfig    = $dialogConfig
        ActionButtons   = $actionButtons
        ActionStates    = $actionStates
        Owner           = $childWin
        ToolManifest    = $ToolManifest
        RequiresNetwork = $requiresNetwork
        OfflineMessage  = $offlineMessage
    }

    $runCallback = [EventCallback]::new()
    $runCallback.ArgumentList = $runState
    $runCallback.ScriptBlock = {
        param($state, $sender, $e)

        $scriptParameters = @{}
        $savedValues = @{}
        $resultOutputBindings = [System.Collections.ArrayList]::new()

        foreach ($parameter in @($state.ToolManifest.parameters)) {
            $control = $state.InputControls[$parameter.name]
            $parameterType = if ($parameter.PSObject.Properties.Name -contains 'type') { $parameter.type } else { 'String' }
            $processing = Resolve-PacParameterProcessing -ParameterDefinition $parameter -Control $control -ToolManifest $state.ToolManifest
            if (-not $processing.IsValid) {
                Reset-PacRunSurfaceState -ResultBox $state.ResultBox -StatusBlock $state.StatusBlock -ActionButtons $state.ActionButtons -ActionStates $state.ActionStates -ClearResultDisplay
                Show-PacParameterValidationDialog -DialogConfig $state.DialogConfig -ErrorKind $processing.ErrorKind -Message $processing.ErrorMessage -Owner $state.Owner
                return
            }

            $savedValues[$parameter.name] = $processing.SavedValue

            if ($processing.IncludeInScript) {
                $scriptParameters[$parameter.name] = $processing.ScriptValue
            }

            if ((Test-PacControlHasTextProperty -Control $control) -and $processing.UpdatedControlValue -and ($processing.UpdatedControlValue -ne [string]$control.Text)) {
                $control.Text = [string]$processing.UpdatedControlValue
                $savedValues[$parameter.name] = [string]$processing.UpdatedControlValue
            }

            if ($processing.ResultOutputBinding) {
                [void]$resultOutputBindings.Add($processing.ResultOutputBinding)
            }
        }

        if ($state.RequiresNetwork -and -not (Test-PacNetworkAvailability)) {
            Reset-PacRunSurfaceState -ResultBox $state.ResultBox -StatusBlock $state.StatusBlock -ActionButtons $state.ActionButtons -ActionStates $state.ActionStates -ClearResultDisplay
            $offlineTitle = Get-PacToolDialogText -DialogConfig $state.DialogConfig -PropertyName 'offlineTitle' -DefaultValue 'Offline'
            $offlineDialogMessage = Get-PacToolDialogText -DialogConfig $state.DialogConfig -PropertyName 'offlineMessage' -DefaultValue $state.OfflineMessage
            Show-PacDialog -Title $offlineTitle -Content $offlineDialogMessage -Owner $state.Owner
            return
        }

        try {
            $runSurfaceUpdated = $false
            $result = & $state.ToolManifest.scriptPath @scriptParameters
            $showSuccessDialog = $false
            $successTitle = $null
            $successMessage = $null
            $formattedResult = Format-PacToolResult -Result $result -ResultConfig $state.ResultConfig
            $outputFiles = @{}
            $skippedOutputs = [System.Collections.ArrayList]::new()

            foreach ($outputBinding in $resultOutputBindings) {
                $saveOutcome = Save-PacToolResultOutput -OutputBinding $outputBinding -RawResult $result -FormattedResult $formattedResult -Owner $state.Owner
                if ($saveOutcome.Status -eq 'saved' -and -not [string]::IsNullOrWhiteSpace([string]$saveOutcome.Path)) {
                    $outputFiles[$outputBinding.ParameterName] = [string]$saveOutcome.Path
                } elseif ($saveOutcome.Status -eq 'skipped' -and -not [string]::IsNullOrWhiteSpace([string]$saveOutcome.Path)) {
                    [void]$skippedOutputs.Add($saveOutcome)
                }
            }

            foreach ($actionState in $state.ActionStates) {
                $actionState.OutputFiles = $outputFiles
            }

            $actionResultText = if (-not [string]::IsNullOrWhiteSpace([string]$formattedResult)) {
                [string]$formattedResult
            } else {
                ''
            }

            foreach ($actionState in $state.ActionStates) {
                $actionState.CurrentResultText = $actionResultText
            }

            $savedOutputSummary = Get-PacSavedOutputSummary -OutputFiles $outputFiles
            $skippedOutputSummary = Get-PacSkippedOutputSummary -SkippedOutputs $skippedOutputs
            if ($state.StatusBlock) {
                if ($savedOutputSummary -or $skippedOutputSummary) {
                    $statusTemplate = if ($state.ResultConfig -and ($state.ResultConfig.PSObject.Properties.Name -contains 'savedOutputText') -and $state.ResultConfig.savedOutputText) {
                        [string]$state.ResultConfig.savedOutputText
                    } elseif ($savedOutputSummary -and $skippedOutputSummary) {
                        '{savedOutputSummary}`r`n{skippedOutputSummary}'
                    } elseif ($savedOutputSummary) {
                        '{savedOutputSummary}'
                    } else {
                        '{skippedOutputSummary}'
                    }
                    $state.StatusBlock.Text = Expand-PacMessageTemplate -Template $statusTemplate -SavedOutputSummary $savedOutputSummary -SkippedOutputSummary $skippedOutputSummary
                } else {
                    $state.StatusBlock.Text = ''
                }
            }

            if ($state.ResultBox) {
                if (-not [string]::IsNullOrWhiteSpace($formattedResult)) {
                    $state.ResultBox.Text = $formattedResult
                    for ($i = 0; $i -lt $state.ActionButtons.Count; $i++) {
                        $button = $state.ActionButtons[$i]
                        $actionState = $state.ActionStates[$i]
                        $button.IsEnabled = Test-PacActionHasTarget -ActionConfig $actionState.ActionConfig -ResultText $actionResultText -OutputFiles $outputFiles
                    }

                    if ($state.DialogConfig -and (($state.DialogConfig.PSObject.Properties.Name -contains 'successTitle') -or ($state.DialogConfig.PSObject.Properties.Name -contains 'successMessage'))) {
                        $showSuccessDialog = $true
                        $successTitle = Get-PacToolDialogText -DialogConfig $state.DialogConfig -PropertyName 'successTitle' -DefaultValue 'Success'
                        $successMessage = Get-PacToolDialogText -DialogConfig $state.DialogConfig -PropertyName 'successMessage' -DefaultValue 'The tool completed successfully.'
                    }
                } else {
                    $state.ResultBox.Text = if ($state.ResultConfig -and ($state.ResultConfig.PSObject.Properties.Name -contains 'noResultText') -and $state.ResultConfig.noResultText) {
                        $state.ResultConfig.noResultText
                    } else {
                        ''
                    }

                    for ($i = 0; $i -lt $state.ActionButtons.Count; $i++) {
                        $button = $state.ActionButtons[$i]
                        $actionState = $state.ActionStates[$i]
                        $button.IsEnabled = Test-PacActionHasTarget -ActionConfig $actionState.ActionConfig -ResultText $actionResultText -OutputFiles $outputFiles
                    }

                    if ($state.DialogConfig -and (($state.DialogConfig.PSObject.Properties.Name -contains 'noResultTitle') -or ($state.DialogConfig.PSObject.Properties.Name -contains 'noResultMessage'))) {
                        $showSuccessDialog = $true
                        $successTitle = Get-PacToolDialogText -DialogConfig $state.DialogConfig -PropertyName 'noResultTitle' -DefaultValue 'Completed'
                        $successMessage = Get-PacToolDialogText -DialogConfig $state.DialogConfig -PropertyName 'noResultMessage' -DefaultValue $state.ResultBox.Text
                    }
                }
            } elseif ($state.DialogConfig -and (($state.DialogConfig.PSObject.Properties.Name -contains 'successTitle') -or ($state.DialogConfig.PSObject.Properties.Name -contains 'successMessage'))) {
                $showSuccessDialog = $true
                $successTitle = Get-PacToolDialogText -DialogConfig $state.DialogConfig -PropertyName 'successTitle' -DefaultValue 'Success'
                $successMessage = Get-PacToolDialogText -DialogConfig $state.DialogConfig -PropertyName 'successMessage' -DefaultValue 'The tool completed successfully.'
            }

            $runSurfaceUpdated = $true

            if ($savedOutputSummary) {
                $savedOutputTitle = Get-PacToolDialogText -DialogConfig $state.DialogConfig -PropertyName 'savedOutputTitle' -DefaultValue 'Saved Output'
                $savedOutputMessageTemplate = Get-PacToolDialogText -DialogConfig $state.DialogConfig -PropertyName 'savedOutputMessage' -DefaultValue '{savedOutputSummary}'
                $savedOutputMessage = Expand-PacMessageTemplate -Template $savedOutputMessageTemplate -SavedOutputSummary $savedOutputSummary -SkippedOutputSummary $skippedOutputSummary

                if ($showSuccessDialog) {
                    $successMessage = if ([string]::IsNullOrWhiteSpace([string]$successMessage)) {
                        $savedOutputMessage
                    } else {
                        "$successMessage`r`n`r`n$savedOutputMessage"
                    }
                } else {
                    $showSuccessDialog = $true
                    $successTitle = $savedOutputTitle
                    $successMessage = $savedOutputMessage
                }
            }

            if ($skippedOutputSummary) {
                $skippedOutputTitle = Get-PacToolDialogText -DialogConfig $state.DialogConfig -PropertyName 'skippedOutputTitle' -DefaultValue 'Output Not Written'
                $skippedOutputMessageTemplate = Get-PacToolDialogText -DialogConfig $state.DialogConfig -PropertyName 'skippedOutputMessage' -DefaultValue '{skippedOutputSummary}'
                $skippedOutputMessage = Expand-PacMessageTemplate -Template $skippedOutputMessageTemplate -SavedOutputSummary $savedOutputSummary -SkippedOutputSummary $skippedOutputSummary

                if ($showSuccessDialog) {
                    $successMessage = if ([string]::IsNullOrWhiteSpace([string]$successMessage)) {
                        $skippedOutputMessage
                    } else {
                        "$successMessage`r`n`r`n$skippedOutputMessage"
                    }
                } else {
                    $showSuccessDialog = $true
                    $successTitle = $skippedOutputTitle
                    $successMessage = $skippedOutputMessage
                }
            }

            Save-PacToolConfig -ConfigPath $state.ToolManifest.configPath -SavedValues $savedValues

            if ($showSuccessDialog) {
                Show-PacDialog -Title $successTitle -Content $successMessage -Owner $state.Owner
            }
        }
        catch {
            if (-not $runSurfaceUpdated) {
                Reset-PacRunSurfaceState -ResultBox $state.ResultBox -StatusBlock $state.StatusBlock -ActionButtons $state.ActionButtons -ActionStates $state.ActionStates -ClearResultDisplay
            }
            $errorTitle = Get-PacToolDialogText -DialogConfig $state.DialogConfig -PropertyName 'errorTitle' -DefaultValue 'Error'
            $errorMessage = Get-PacToolDialogText -DialogConfig $state.DialogConfig -PropertyName 'errorMessage' -DefaultValue $_.Exception.Message
            Show-PacDialog -Title $errorTitle -Content $errorMessage -Owner $state.Owner
        }
    }

    $primaryButton.AddClick($runCallback)

    Set-PacChildWindowContent -Window $childWin -Content $root -WrapInScrollViewer
    $childWin.Activate()

    return $childWin
}