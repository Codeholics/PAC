using namespace WinUIShell
using namespace WinUIShell.Microsoft.UI
using namespace WinUIShell.Microsoft.UI.Xaml
using namespace WinUIShell.Microsoft.UI.Xaml.Controls
using namespace WinUIShell.Microsoft.UI.Xaml.Media

function Get-EnterpriseUserAuditConfigEntry {
    param(
        [AllowNull()]
        $Config,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $Config) {
        return $null
    }

    if ((Test-PacToolConfigSaveValuesEnabled -Config $Config) -and ($Config.PSObject.Properties.Name -contains 'savedValues')) {
        $savedValues = $Config.savedValues
        if ($null -ne $savedValues -and ($savedValues.PSObject.Properties.Name -contains $Name)) {
            $savedValue = $savedValues.$Name
            if ($savedValue -is [System.Array]) {
                return @($savedValue)
            }

            if ($savedValue -is [bool] -or $savedValue -is [int] -or $savedValue -is [double]) {
                return $savedValue
            }

            if ($null -ne $savedValue -and -not [string]::IsNullOrWhiteSpace([string]$savedValue)) {
                return $savedValue
            }

            if ($savedValue -eq $false) {
                return $false
            }
        }
    }

    if ($Config.PSObject.Properties.Name -contains 'defaults') {
        $defaults = $Config.defaults
        if ($null -ne $defaults -and ($defaults.PSObject.Properties.Name -contains $Name)) {
            $defaultValue = $defaults.$Name
            if ($defaultValue -is [System.Array]) {
                return @($defaultValue)
            }

            return $defaultValue
        }
    }

    return $null
}

function Get-EnterpriseUserAuditSelectedColumns {
    param(
        [Parameter(Mandatory)]
        [hashtable]$ColumnControls,

        [string[]]$FallbackColumns
    )

    $selectedColumns = foreach ($columnName in $ColumnControls.Keys) {
        if ($ColumnControls[$columnName].IsChecked -eq $true) {
            $columnName
        }
    }

    $selectedColumns = @($selectedColumns)
    if ($selectedColumns.Count -gt 0) {
        return $selectedColumns
    }

    return @($FallbackColumns)
}

function Format-EnterpriseUserAuditResultText {
    param(
        [Parameter(Mandatory)]
        $Result,

        [string[]]$SelectedColumns
    )

    $records = @($Result.Records)
    $summaryLines = @(
        ('Source: {0}' -f $Result.Source),
        ('Records: {0}' -f $records.Count)
    )

    if (-not [string]::IsNullOrWhiteSpace([string]$Result.ExportPath)) {
        $summaryLines += ('Export: {0}' -f $Result.ExportPath)
    }

    if ($Result.ModuleStatus) {
        $summaryLines += ''
        $summaryLines += 'Modules:'
        foreach ($property in $Result.ModuleStatus.PSObject.Properties) {
            $summaryLines += ('- {0}: {1}' -f $property.Name, $property.Value)
        }
    }

    if ($records.Count -eq 0) {
        return (($summaryLines + @('', 'No matching users were returned.')) -join [Environment]::NewLine)
    }

    $tableColumns = @($SelectedColumns | Where-Object { $records[0].PSObject.Properties.Name -contains $_ })
    if ($tableColumns.Count -eq 0) {
        $tableColumns = @($records[0].PSObject.Properties.Name)
    }

    $tableText = ($records | Select-Object -Property $tableColumns | Format-Table -AutoSize | Out-String -Width 4096).TrimEnd()

    return (($summaryLines + @('', 'Results:', $tableText)) -join [Environment]::NewLine)
}

function Show-EnterpriseUserAuditWindow {
    $toolManifest = Get-PacToolManifest -RootPath $script:PacRootPath -ManifestPath 'Tools/Enterprise User Audit/tool.json'
    $toolConfig = Get-PacToolConfig -ConfigPath $toolManifest.configPath

    $toolWindow = New-PacChildWindow -Title $toolManifest.window.title -Subtitle $toolManifest.category -Width $toolManifest.window.width -Height $toolManifest.window.height -OwnerWindow $null

    $panel = [StackPanel]::new()
    $panel.Margin = 24
    $panel.Spacing = 12

    $title = [TextBlock]::new()
    $title.Text = $toolManifest.name
    $title.Style = [Application]::Current.Resources['TitleTextBlockStyle']

    $description = [TextBlock]::new()
    $description.Text = $toolManifest.description
    $description.TextWrapping = 'Wrap'

    $identityBox = [TextBox]::new()
    $identityBox.Header = 'Identity'
    $identityBox.PlaceholderText = 'UPN, SAM account name, or email'
    $identityBox.Text = [string](Get-EnterpriseUserAuditConfigEntry -Config $toolConfig -Name 'Identity')

    $titleBox = [TextBox]::new()
    $titleBox.Header = 'Title Filter'
    $titleBox.Text = [string](Get-EnterpriseUserAuditConfigEntry -Config $toolConfig -Name 'Title')

    $managerBox = [TextBox]::new()
    $managerBox.Header = 'Manager Filter'
    $managerBox.Text = [string](Get-EnterpriseUserAuditConfigEntry -Config $toolConfig -Name 'Manager')

    $companyBox = [TextBox]::new()
    $companyBox.Header = 'Company Filter'
    $companyBox.Text = [string](Get-EnterpriseUserAuditConfigEntry -Config $toolConfig -Name 'Company')

    $divisionBox = [TextBox]::new()
    $divisionBox.Header = 'Division Filter'
    $divisionBox.Text = [string](Get-EnterpriseUserAuditConfigEntry -Config $toolConfig -Name 'Division')

    $groupBox = [TextBox]::new()
    $groupBox.Header = 'Group Filter'
    $groupBox.PlaceholderText = 'Optional AD group name'
    $groupBox.Text = [string](Get-EnterpriseUserAuditConfigEntry -Config $toolConfig -Name 'Group')

    $sqlConnectionBox = [TextBox]::new()
    $sqlConnectionBox.Header = 'SQL Connection String'
    $sqlConnectionBox.Text = [string](Get-EnterpriseUserAuditConfigEntry -Config $toolConfig -Name 'SqlConnectionString')

    $exportPathBox = [TextBox]::new()
    $exportPathBox.Header = 'Export Path'
    $exportPathBox.Text = [string](Get-EnterpriseUserAuditConfigEntry -Config $toolConfig -Name 'ExportPath')

    $sampleDataCheckBox = [CheckBox]::new()
    $sampleDataCheckBox.Content = 'Use sample data'
    $sampleDataCheckBox.IsChecked = [bool](Get-EnterpriseUserAuditConfigEntry -Config $toolConfig -Name 'UseSampleData')

    $includeMailboxCheckBox = [CheckBox]::new()
    $includeMailboxCheckBox.Content = 'Include Exchange enrichment when available'
    $includeMailboxCheckBox.IsChecked = [bool](Get-EnterpriseUserAuditConfigEntry -Config $toolConfig -Name 'IncludeMailbox')

    $includeSqlDataCheckBox = [CheckBox]::new()
    $includeSqlDataCheckBox.Content = 'Include SQL enrichment when available'
    $includeSqlDataCheckBox.IsChecked = [bool](Get-EnterpriseUserAuditConfigEntry -Config $toolConfig -Name 'IncludeSqlData')

    $saveValuesCheckBox = [CheckBox]::new()
    $saveValuesCheckBox.Content = 'Save values to config'
    $saveValuesCheckBox.IsChecked = Test-PacToolConfigSaveValuesEnabled -Config $toolConfig

    $saveValuesNote = [TextBlock]::new()
    $saveValuesNote.Text = 'Leave this off to avoid persisting prior search criteria, connection strings, or other sensitive values.'
    $saveValuesNote.TextWrapping = 'Wrap'

    $columnTitle = [TextBlock]::new()
    $columnTitle.Text = 'Columns'
    $columnTitle.Style = [Application]::Current.Resources['SubtitleTextBlockStyle']

    $columnPanel = [StackPanel]::new()
    $columnPanel.Spacing = 8

    $availableColumns = @(
        'DisplayName',
        'SamAccountName',
        'UserPrincipalName',
        'Title',
        'Department',
        'Company',
        'Division',
        'Manager',
        'Enabled',
        'GroupMatch',
        'MailboxSize',
        'ForwardingAddress',
        'EmploymentStatus',
        'Source'
    )

    $defaultColumns = @(
        'DisplayName',
        'SamAccountName',
        'UserPrincipalName',
        'Department',
        'Enabled',
        'Source'
    )

    $configuredColumns = @(Get-EnterpriseUserAuditConfigEntry -Config $toolConfig -Name 'SelectedColumns')
    if ($configuredColumns.Count -eq 0) {
        $configuredColumns = $defaultColumns
    }

    $columnControls = @{}
    foreach ($columnName in $availableColumns) {
        $columnCheckBox = [CheckBox]::new()
        $columnCheckBox.Content = $columnName
        $columnCheckBox.IsChecked = $configuredColumns -contains $columnName
        $columnControls[$columnName] = $columnCheckBox
        $columnPanel.Children.Add($columnCheckBox)
    }

    $buttonPanel = [StackPanel]::new()
    $buttonPanel.Orientation = 'Horizontal'
    $buttonPanel.Spacing = 12

    $runButton = [Button]::new()
    $runButton.Content = 'Run Audit'
    $runButton.Style = [Application]::Current.Resources['AccentButtonStyle']

    $exportButton = [Button]::new()
    $exportButton.Content = 'Run And Export'

    $openOutputButton = [Button]::new()
    $openOutputButton.Content = 'Open Output Folder'

    $resultTitle = [TextBlock]::new()
    $resultTitle.Text = 'Results'
    $resultTitle.Style = [Application]::Current.Resources['SubtitleTextBlockStyle']

    $resultBox = [TextBox]::new()
    $resultBox.AcceptsReturn = $true
    $resultBox.TextWrapping = 'Wrap'
    $resultBox.IsReadOnly = $true
    $resultBox.MinHeight = 280
    $resultBox.PlaceholderText = 'Run the audit to view results.'

    $toolWindow | Add-Member -NotePropertyName PacLastExportPath -NotePropertyValue '' -Force

    $runState = @{
        ToolManifest            = $toolManifest
        ToolWindow              = $toolWindow
        ResultBox               = $resultBox
        ExportResults           = $false
        ColumnControls          = $columnControls
        DefaultColumns          = $defaultColumns
        IdentityBox             = $identityBox
        TitleBox                = $titleBox
        ManagerBox              = $managerBox
        CompanyBox              = $companyBox
        DivisionBox             = $divisionBox
        GroupBox                = $groupBox
        ExportPathBox           = $exportPathBox
        SqlConnectionBox        = $sqlConnectionBox
        SampleDataCheckBox      = $sampleDataCheckBox
        IncludeMailboxCheckBox  = $includeMailboxCheckBox
        IncludeSqlDataCheckBox  = $includeSqlDataCheckBox
        SaveValuesCheckBox      = $saveValuesCheckBox
    }

    $exportState = @{}
    foreach ($key in $runState.Keys) {
        $exportState[$key] = $runState[$key]
    }
    $exportState.ExportResults = $true

    $runCallback = [EventCallback]::new()
    $runCallback.ArgumentList = $runState
    $runCallback.ScriptBlock = {
        param($state, $sender, $e)

        $selectedColumns = Get-EnterpriseUserAuditSelectedColumns -ColumnControls $state.ColumnControls -FallbackColumns $state.DefaultColumns

        $savedValues = @{
            Identity            = $state.IdentityBox.Text
            Title               = $state.TitleBox.Text
            Manager             = $state.ManagerBox.Text
            Company             = $state.CompanyBox.Text
            Division            = $state.DivisionBox.Text
            Group               = $state.GroupBox.Text
            ExportPath          = $state.ExportPathBox.Text
            SqlConnectionString = $state.SqlConnectionBox.Text
            UseSampleData       = [bool]($state.SampleDataCheckBox.IsChecked -eq $true)
            IncludeMailbox      = [bool]($state.IncludeMailboxCheckBox.IsChecked -eq $true)
            IncludeSqlData      = [bool]($state.IncludeSqlDataCheckBox.IsChecked -eq $true)
            SelectedColumns     = @($selectedColumns)
        }

        Save-PacToolConfig -ConfigPath $state.ToolManifest.configPath -SavedValues $savedValues -SaveValuesEnabled ([bool]($state.SaveValuesCheckBox.IsChecked -eq $true))

        try {
            $invokeParameters = @{
                Identity            = $state.IdentityBox.Text
                Title               = $state.TitleBox.Text
                Manager             = $state.ManagerBox.Text
                Company             = $state.CompanyBox.Text
                Division            = $state.DivisionBox.Text
                Group               = $state.GroupBox.Text
                SelectedColumns     = $selectedColumns
                UseSampleData       = [bool]($state.SampleDataCheckBox.IsChecked -eq $true)
                IncludeMailbox      = [bool]($state.IncludeMailboxCheckBox.IsChecked -eq $true)
                IncludeSqlData      = [bool]($state.IncludeSqlDataCheckBox.IsChecked -eq $true)
                ExportResults       = [bool]$state.ExportResults
                ExportPath          = $state.ExportPathBox.Text
                SqlConnectionString = $state.SqlConnectionBox.Text
            }

            $result = & $state.ToolManifest.scriptPath @invokeParameters

            $state.ToolWindow.PacLastExportPath = [string]$result.ExportPath
            $state.ResultBox.Text = Format-EnterpriseUserAuditResultText -Result $result -SelectedColumns $selectedColumns
        }
        catch {
            $state.ResultBox.Text = ''
            Show-PacDialog -Title 'Enterprise User Audit failed' -Content $_.Exception.Message -Owner $state.ToolWindow
        }
    }
    $runButton.AddClick($runCallback)

    $exportCallback = [EventCallback]::new()
    $exportCallback.ArgumentList = $exportState
    $exportCallback.ScriptBlock = {
        param($state, $sender, $e)

        $selectedColumns = Get-EnterpriseUserAuditSelectedColumns -ColumnControls $state.ColumnControls -FallbackColumns $state.DefaultColumns

        $savedValues = @{
            Identity            = $state.IdentityBox.Text
            Title               = $state.TitleBox.Text
            Manager             = $state.ManagerBox.Text
            Company             = $state.CompanyBox.Text
            Division            = $state.DivisionBox.Text
            Group               = $state.GroupBox.Text
            ExportPath          = $state.ExportPathBox.Text
            SqlConnectionString = $state.SqlConnectionBox.Text
            UseSampleData       = [bool]($state.SampleDataCheckBox.IsChecked -eq $true)
            IncludeMailbox      = [bool]($state.IncludeMailboxCheckBox.IsChecked -eq $true)
            IncludeSqlData      = [bool]($state.IncludeSqlDataCheckBox.IsChecked -eq $true)
            SelectedColumns     = @($selectedColumns)
        }

        Save-PacToolConfig -ConfigPath $state.ToolManifest.configPath -SavedValues $savedValues -SaveValuesEnabled ([bool]($state.SaveValuesCheckBox.IsChecked -eq $true))

        try {
            $invokeParameters = @{
                Identity            = $state.IdentityBox.Text
                Title               = $state.TitleBox.Text
                Manager             = $state.ManagerBox.Text
                Company             = $state.CompanyBox.Text
                Division            = $state.DivisionBox.Text
                Group               = $state.GroupBox.Text
                SelectedColumns     = $selectedColumns
                UseSampleData       = [bool]($state.SampleDataCheckBox.IsChecked -eq $true)
                IncludeMailbox      = [bool]($state.IncludeMailboxCheckBox.IsChecked -eq $true)
                IncludeSqlData      = [bool]($state.IncludeSqlDataCheckBox.IsChecked -eq $true)
                ExportResults       = [bool]$state.ExportResults
                ExportPath          = $state.ExportPathBox.Text
                SqlConnectionString = $state.SqlConnectionBox.Text
            }

            $result = & $state.ToolManifest.scriptPath @invokeParameters

            $state.ToolWindow.PacLastExportPath = [string]$result.ExportPath
            $state.ResultBox.Text = Format-EnterpriseUserAuditResultText -Result $result -SelectedColumns $selectedColumns
        }
        catch {
            $state.ResultBox.Text = ''
            Show-PacDialog -Title 'Enterprise User Audit failed' -Content $_.Exception.Message -Owner $state.ToolWindow
        }
    }
    $exportButton.AddClick($exportCallback)

    $openOutputCallback = [EventCallback]::new()
    $openOutputCallback.ArgumentList = $runState
    $openOutputCallback.ScriptBlock = {
        param($state, $sender, $e)

        $targetPath = [string]$state.ToolWindow.PacLastExportPath
        if ([string]::IsNullOrWhiteSpace($targetPath) -or -not (Test-Path -LiteralPath $targetPath)) {
            Show-PacDialog -Title 'No output available' -Content 'Run an export before opening the output folder.' -Owner $state.ToolWindow
            return
        }

        $resolvedPath = (Resolve-Path -LiteralPath $targetPath).Path
        Start-Process explorer.exe ("/select,`"{0}`"" -f $resolvedPath) | Out-Null
    }
    $openOutputButton.AddClick($openOutputCallback)

    $buttonPanel.Children.Add($runButton)
    $buttonPanel.Children.Add($exportButton)
    $buttonPanel.Children.Add($openOutputButton)

    $panel.Children.Add($title)
    $panel.Children.Add($description)
    $panel.Children.Add($identityBox)
    $panel.Children.Add($titleBox)
    $panel.Children.Add($managerBox)
    $panel.Children.Add($companyBox)
    $panel.Children.Add($divisionBox)
    $panel.Children.Add($groupBox)
    $panel.Children.Add($sqlConnectionBox)
    $panel.Children.Add($exportPathBox)
    $panel.Children.Add($sampleDataCheckBox)
    $panel.Children.Add($includeMailboxCheckBox)
    $panel.Children.Add($includeSqlDataCheckBox)
    $panel.Children.Add($saveValuesCheckBox)
    $panel.Children.Add($saveValuesNote)
    $panel.Children.Add($columnTitle)
    $panel.Children.Add($columnPanel)
    $panel.Children.Add($buttonPanel)
    $panel.Children.Add($resultTitle)
    $panel.Children.Add($resultBox)

    Set-PacChildWindowContent -Window $toolWindow -Content $panel -WrapInScrollViewer
    $toolWindow.Activate()
}

function Get-EnterpriseUserAuditPage {
    param([hashtable]$Context)

    $toolManifest = Get-PacToolManifest -RootPath $Context.RootPath -ManifestPath 'Tools/Enterprise User Audit/tool.json'

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
        Description = $toolManifest.description

        Icon = @{
            Type       = 'FontIcon'
            Glyph      = [char]0xE7BA
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
            $text.Text = 'Custom PAC workflow for cross-source user review, with a prototype-safe sample-data mode and optional enterprise enrichments when dependencies are available.'
            $text.TextWrapping = 'Wrap'
            $text.Style = $pageContext.Resources['BodyTextBlockStyle']

            $button = [Button]::new()
            $button.Content = 'Open Workflow'
            $button.Style = $pageContext.Resources['AccentButtonStyle']

            $openToolCallback = [EventCallback]::new()
            $openToolCallback.ScriptBlock = {
                Show-EnterpriseUserAuditWindow
            }
            $button.AddClick($openToolCallback)

            $panel.Children.Add($title)
            $panel.Children.Add($text)
            $panel.Children.Add($button)

            $page.Content = $panel
        }
    }
}