function Resolve-PacPickerDirectory {
    param(
        [AllowNull()]
        $PickerConfig,

        [AllowNull()]
        $ToolManifest,

        [AllowNull()]
        $CurrentValue
    )

    $resolvedPath = $null

    if ($PickerConfig) {
        if (($PickerConfig.PSObject.Properties.Name -contains 'initialDirectoryProperty') -and $ToolManifest) {
            $propertyName = [string]$PickerConfig.initialDirectoryProperty
            if ($ToolManifest.PSObject.Properties.Name -contains $propertyName) {
                $resolvedPath = $ToolManifest.$propertyName
            }
        }

        if (-not $resolvedPath -and ($PickerConfig.PSObject.Properties.Name -contains 'initialDirectory') -and $PickerConfig.initialDirectory) {
            $resolvedPath = [string]$PickerConfig.initialDirectory
        }
    }

    if (-not $resolvedPath -and -not [string]::IsNullOrWhiteSpace([string]$CurrentValue)) {
        $currentPath = [string]$CurrentValue
        if (Test-Path -LiteralPath $currentPath) {
            $resolvedPath = if ((Get-Item -LiteralPath $currentPath).PSIsContainer) {
                $currentPath
            } else {
                Split-Path -Path $currentPath -Parent
            }
        }
    }

    if (-not $resolvedPath) {
        return $null
    }

    if ([System.IO.Path]::IsPathRooted($resolvedPath) -or -not $ToolManifest -or -not $ToolManifest.toolPath) {
        return $resolvedPath
    }

    return Join-Path -Path $ToolManifest.toolPath -ChildPath $resolvedPath
}

function New-PacToolTextInput {
    param(
        [Parameter(Mandatory)]
        $Resources,

        [Parameter(Mandatory)]
        $ParameterDefinition,

        $Value = $null,

        $Owner = $null,

        $ToolManifest = $null
    )

    $container = [WinUIShell.Microsoft.UI.Xaml.Controls.StackPanel]::new()
    $container.Spacing = 8

    $label = [WinUIShell.Microsoft.UI.Xaml.Controls.TextBlock]::new()
    $label.Text = if ($ParameterDefinition.label) { $ParameterDefinition.label } else { $ParameterDefinition.name }
    $label.Style = $Resources['BodyTextBlockStyle']

    $descriptionBlock = $null
    if ($ParameterDefinition.description) {
        $descriptionBlock = [WinUIShell.Microsoft.UI.Xaml.Controls.TextBlock]::new()
        $descriptionBlock.Text = [string]$ParameterDefinition.description
        $descriptionBlock.TextWrapping = 'Wrap'
        $descriptionBlock.Style = $Resources['BodyTextBlockStyle']
        $descriptionBlock.Opacity = 0.8
    }

    $parameterType = if (($ParameterDefinition.PSObject.Properties.Name -contains 'type') -and $ParameterDefinition.type) {
        [string]$ParameterDefinition.type
    } else {
        'String'
    }

    $isBoolean = $parameterType -eq 'Boolean'
    $isNumber = $parameterType -eq 'Number'
    $hasAllowedValues = ($ParameterDefinition.PSObject.Properties.Name -contains 'allowedValues') -and @($ParameterDefinition.allowedValues).Count -gt 0
    $controlType = if (($ParameterDefinition.PSObject.Properties.Name -contains 'control') -and $ParameterDefinition.control) {
        [string]$ParameterDefinition.control
    } else {
        ''
    }
    $isFolderPicker = $parameterType -eq 'Folder' -or $controlType -eq 'FolderPicker'
    $isFilePicker = $parameterType -eq 'File' -or $controlType -eq 'FilePicker'

    if ($isBoolean) {
        $input = [WinUIShell.Microsoft.UI.Xaml.Controls.CheckBox]::new()
        $input.IsChecked = if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
            $false
        } else {
            [System.Convert]::ToBoolean($Value)
        }
    } elseif ($hasAllowedValues) {
        $input = [WinUIShell.Microsoft.UI.Xaml.Controls.ComboBox]::new()
        $input.PlaceholderText = if ($ParameterDefinition.description) { $ParameterDefinition.description } else { "Select $($ParameterDefinition.name)..." }

        foreach ($allowedValue in @($ParameterDefinition.allowedValues)) {
            [void]$input.Items.Add([string]$allowedValue)
        }

        if ($null -ne $Value -and -not [string]::IsNullOrWhiteSpace([string]$Value)) {
            $input.SelectedItem = [string]$Value
        }
    } else {
        $input = [WinUIShell.Microsoft.UI.Xaml.Controls.TextBox]::new()
        $input.PlaceHolderText = if ($ParameterDefinition.description) { $ParameterDefinition.description } else { "Enter $($ParameterDefinition.name)..." }
        $input.Text = if ($null -eq $Value) { '' } else { [string]$Value }

        $isMultiline = (($ParameterDefinition.PSObject.Properties.Name -contains 'control') -and $ParameterDefinition.control -eq 'TextArea') -or
            (($ParameterDefinition.PSObject.Properties.Name -contains 'multiline') -and [bool]$ParameterDefinition.multiline)

        if ($isMultiline) {
            $input.AcceptsReturn = $true
            $input.TextWrapping = 'Wrap'
            $input.MinHeight = if (($ParameterDefinition.PSObject.Properties.Name -contains 'minHeight') -and $ParameterDefinition.minHeight) {
                [double]$ParameterDefinition.minHeight
            } else {
                120
            }
        } elseif ($isNumber) {
            $input.TextAlignment = 'Right'
        }
    }

    $inputPresenter = $input

    if (($isFolderPicker -or $isFilePicker) -and $input -is [WinUIShell.Microsoft.UI.Xaml.Controls.TextBox]) {
        $pickerConfig = if (($ParameterDefinition.PSObject.Properties.Name -contains 'pathPicker') -and $ParameterDefinition.pathPicker) {
            $ParameterDefinition.pathPicker
        } else {
            $null
        }

        $pickerPanel = [WinUIShell.Microsoft.UI.Xaml.Controls.StackPanel]::new()
        $pickerPanel.Orientation = 'Horizontal'
        $pickerPanel.Spacing = 12

        $browseButton = [WinUIShell.Microsoft.UI.Xaml.Controls.Button]::new()
        $browseButton.Content = if ($pickerConfig -and ($pickerConfig.PSObject.Properties.Name -contains 'label') -and $pickerConfig.label) {
            $pickerConfig.label
        } elseif ($isFolderPicker) {
            'Browse Folder'
        } else {
            'Browse File'
        }

        $browseState = @{
            Input      = $input
            Owner      = $Owner
            PickerType = if ($isFolderPicker) { 'Folder' } else { 'File' }
            Filter     = if ($pickerConfig -and ($pickerConfig.PSObject.Properties.Name -contains 'filter') -and $pickerConfig.filter) { [string]$pickerConfig.filter } else { 'All files (*.*)|*.*' }
            PickerConfig = $pickerConfig
            ToolManifest = $ToolManifest
            Title      = if ($pickerConfig -and ($pickerConfig.PSObject.Properties.Name -contains 'title') -and $pickerConfig.title) {
                [string]$pickerConfig.title
            } elseif ($isFolderPicker) {
                'Select a folder'
            } else {
                'Select a file'
            }
            FileName = if ($pickerConfig -and ($pickerConfig.PSObject.Properties.Name -contains 'fileName') -and $pickerConfig.fileName) { [string]$pickerConfig.fileName } else { '' }
            DefaultExtension = if ($pickerConfig -and ($pickerConfig.PSObject.Properties.Name -contains 'defaultExtension') -and $pickerConfig.defaultExtension) { [string]$pickerConfig.defaultExtension } else { '' }
            CheckFileExists = if ($pickerConfig -and ($pickerConfig.PSObject.Properties.Name -contains 'checkFileExists')) { [bool]$pickerConfig.checkFileExists } else { $true }
            ShowNewFolderButton = if ($pickerConfig -and ($pickerConfig.PSObject.Properties.Name -contains 'showNewFolderButton')) { [bool]$pickerConfig.showNewFolderButton } else { $true }
            PickerMode = if ($pickerConfig -and ($pickerConfig.PSObject.Properties.Name -contains 'mode') -and $pickerConfig.mode) { [string]$pickerConfig.mode } else { 'open' }
        }

        $browseCallback = [WinUIShell.EventCallback]::new()
        $browseCallback.ArgumentList = $browseState
        $browseCallback.ScriptBlock = {
            param($state, $sender, $e)

            try {
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
                $initialDirectory = Resolve-PacPickerDirectory -PickerConfig $state.PickerConfig -ToolManifest $state.ToolManifest -CurrentValue $state.Input.Text

                if ($state.PickerType -eq 'Folder') {
                    $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
                    $dialog.Description = $state.Title
                    $dialog.ShowNewFolderButton = $state.ShowNewFolderButton

                    if ($initialDirectory) {
                        $dialog.SelectedPath = $initialDirectory
                    }

                    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                        $state.Input.Text = $dialog.SelectedPath
                    }
                } else {
                    if ($state.PickerMode -eq 'save') {
                        $dialog = [System.Windows.Forms.SaveFileDialog]::new()
                        $dialog.Filter = $state.Filter
                        $dialog.Title = $state.Title
                        $dialog.OverwritePrompt = $true
                        if ($state.DefaultExtension) {
                            $dialog.DefaultExt = $state.DefaultExtension
                            $dialog.AddExtension = $true
                        }
                        if ($state.FileName) {
                            $dialog.FileName = $state.FileName
                        }
                    } else {
                        $dialog = [System.Windows.Forms.OpenFileDialog]::new()
                        $dialog.Filter = $state.Filter
                        $dialog.Title = $state.Title
                        $dialog.Multiselect = $false
                        $dialog.CheckFileExists = $state.CheckFileExists
                    }

                    if ($initialDirectory) {
                        $dialog.InitialDirectory = $initialDirectory
                    }

                    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                        $state.Input.Text = $dialog.FileName
                    }
                }
            }
            catch {
                if ($state.Owner) {
                    Show-PacDialog -Title 'Picker Error' -Content $_.Exception.Message -Owner $state.Owner
                }
            }
        }

        $browseButton.AddClick($browseCallback)
        $pickerPanel.Children.Add($input)
        $pickerPanel.Children.Add($browseButton)
        $inputPresenter = $pickerPanel
    }

    $container.Children.Add($label)

    if ($descriptionBlock) {
        $container.Children.Add($descriptionBlock)
    }

    if (($ParameterDefinition.PSObject.Properties.Name -contains 'fileImport') -and $ParameterDefinition.fileImport -and $input -is [WinUIShell.Microsoft.UI.Xaml.Controls.TextBox]) {
        $importConfig = $ParameterDefinition.fileImport

        $importButton = [WinUIShell.Microsoft.UI.Xaml.Controls.Button]::new()
        $importButton.Content = if (($importConfig.PSObject.Properties.Name -contains 'label') -and $importConfig.label) { $importConfig.label } else { 'Import File' }

        $importState = @{
            Input  = $input
            Owner  = $Owner
            Filter = if (($importConfig.PSObject.Properties.Name -contains 'filter') -and $importConfig.filter) { [string]$importConfig.filter } else { 'All files (*.*)|*.*' }
            InitialDirectory = Resolve-PacPickerDirectory -PickerConfig $importConfig -ToolManifest $ToolManifest -CurrentValue $null
            Title  = if (($importConfig.PSObject.Properties.Name -contains 'title') -and $importConfig.title) { [string]$importConfig.title } else { 'Select a file' }
            CheckFileExists = if (($importConfig.PSObject.Properties.Name -contains 'checkFileExists')) { [bool]$importConfig.checkFileExists } else { $true }
        }

        $importCallback = [WinUIShell.EventCallback]::new()
        $importCallback.ArgumentList = $importState
        $importCallback.ScriptBlock = {
            param($state, $sender, $e)

            try {
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue

                $dialog = [System.Windows.Forms.OpenFileDialog]::new()
                $dialog.Filter = $state.Filter
                $dialog.Title = $state.Title
                $dialog.Multiselect = $false
                $dialog.CheckFileExists = $state.CheckFileExists

                if ($state.InitialDirectory) {
                    $dialog.InitialDirectory = $state.InitialDirectory
                }

                if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    $state.Input.Text = [System.IO.File]::ReadAllText($dialog.FileName)
                }
            }
            catch {
                if ($state.Owner) {
                    Show-PacDialog -Title 'Import Error' -Content $_.Exception.Message -Owner $state.Owner
                }
            }
        }

        $importButton.AddClick($importCallback)
        $container.Children.Add($importButton)
    }

    $container.Children.Add($inputPresenter)

    return [pscustomobject]@{
        Container = $container
        Label     = $label
        Input     = $input
    }
}