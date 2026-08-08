using namespace WinUIShell
using namespace WinUIShell.Microsoft.UI
using namespace WinUIShell.Microsoft.UI.Xaml
using namespace WinUIShell.Microsoft.UI.Xaml.Controls
using namespace WinUIShell.Microsoft.UI.Xaml.Media

function Get-PacSessionReadinessConfigEntry {
    param(
        [AllowNull()]
        $Config,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $Config) {
        return $null
    }

    $propertyNames = @('defaults')
    if (Test-PacToolConfigSaveValuesEnabled -Config $Config) {
        $propertyNames = @('savedValues', 'defaults')
    }

    foreach ($propertyName in $propertyNames) {
        if ($Config.PSObject.Properties.Name -contains $propertyName) {
            $source = $Config.$propertyName
            if ($null -ne $source -and ($source.PSObject.Properties.Name -contains $Name)) {
                return $source.$Name
            }
        }
    }

    return $null
}

function Format-PacSessionReadinessResultText {
    param(
        [Parameter(Mandatory)]
        $Result
    )

    $lines = @(
        'Runtime',
        ('- PowerShell: {0} ({1})' -f $Result.Runtime.PowerShellVersion, $Result.Runtime.PSEdition),
        ('- WinUIShell Available: {0}' -f $Result.Runtime.WinUIShellAvailable),
        ('- User: {0}' -f $Result.Runtime.CurrentUser),
        ('- Machine: {0}' -f $Result.Runtime.MachineName),
        ('- Timestamp: {0}' -f $Result.Runtime.Timestamp),
        '',
        'Authentication',
        ('- Provider: {0}' -f $Result.Authentication.Provider),
        ('- Domain Joined: {0}' -f $Result.Authentication.DomainJoined),
        ('- Domain: {0}' -f $Result.Authentication.DomainName),
        ('- Domain Controller Reachable: {0}' -f $Result.Authentication.DomainControllerReachable),
        ('- Reason: {0}' -f $Result.Authentication.Reason),
        '',
        'Environment',
        ('- Network Available: {0}' -f $Result.Environment.NetworkAvailable),
        ('- Domain Connected: {0}' -f $Result.Environment.DomainConnected),
        '',
        'Capabilities',
        ('- GeneralToolsReady: {0}' -f $Result.Capabilities.GeneralToolsReady),
        ('- ADToolsReady: {0}' -f $Result.Capabilities.ADToolsReady),
        ('- ExchangeOnlineToolsReady: {0}' -f $Result.Capabilities.ExchangeOnlineToolsReady),
        ('- ExchangeOnPremToolsReady: {0}' -f $Result.Capabilities.ExchangeOnPremToolsReady),
        ('- ExchangeToolsReady: {0}' -f $Result.Capabilities.ExchangeToolsReady),
        ('- SqlToolsReady: {0}' -f $Result.Capabilities.SqlToolsReady),
        ('- ExportReady: {0}' -f $Result.Capabilities.ExportReady),
        ('- LoggingReady: {0}' -f $Result.Capabilities.LoggingReady),
        ('- EnterpriseWorkflowsReady: {0}' -f $Result.Capabilities.EnterpriseWorkflowsReady),
        '',
        'Modules',
        (($Result.Modules | Format-Table Name, Available, Loaded, RequiredBy -AutoSize | Out-String -Width 4096).TrimEnd()),
        '',
        'Tests',
        (($Result.Tests | Format-Table Name, Status, Message -AutoSize | Out-String -Width 4096).TrimEnd()),
        '',
        'Tool Readiness',
        (($Result.ToolReadiness | Format-Table Tool, Status, Reason -AutoSize | Out-String -Width 4096).TrimEnd())
    )

    return ($lines -join [Environment]::NewLine)
}

function Show-PacSessionReadinessWindow {
    $toolManifest = Get-PacToolManifest -RootPath $script:PacRootPath -ManifestPath 'Tools/PAC Session Readiness Center/tool.json'
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

    $sqlConnectionBox = [TextBox]::new()
    $sqlConnectionBox.Header = 'SQL Connection String'
    $sqlConnectionBox.PlaceholderText = 'Optional; only used when SQL test is requested'
    $sqlConnectionBox.Text = [string](Get-PacSessionReadinessConfigEntry -Config $toolConfig -Name 'SqlConnectionString')

    $exchangeCheckBox = [CheckBox]::new()
    $exchangeCheckBox.Content = 'Run Exchange Online and on-prem session tests'
    $exchangeCheckBox.IsChecked = [bool](Get-PacSessionReadinessConfigEntry -Config $toolConfig -Name 'RunExchangeTest')

    $sqlCheckBox = [CheckBox]::new()
    $sqlCheckBox.Content = 'Run SQL connection test'
    $sqlCheckBox.IsChecked = [bool](Get-PacSessionReadinessConfigEntry -Config $toolConfig -Name 'RunSqlTest')

    $loggingCheckBox = [CheckBox]::new()
    $loggingCheckBox.Content = 'Run logging write test'
    $loggingCheckBox.IsChecked = [bool](Get-PacSessionReadinessConfigEntry -Config $toolConfig -Name 'RunLoggingTest')

    $saveValuesCheckBox = [CheckBox]::new()
    $saveValuesCheckBox.Content = 'Save values to config'
    $saveValuesCheckBox.IsChecked = Test-PacToolConfigSaveValuesEnabled -Config $toolConfig

    $saveValuesNote = [TextBlock]::new()
    $saveValuesNote.Text = 'Leave this off to avoid persisting connection strings or prior test selections between sessions.'
    $saveValuesNote.TextWrapping = 'Wrap'

    $note = [TextBlock]::new()
    $note.Text = 'Authentication and AD reachability are always assessed. SQL, Exchange Online, Exchange on-prem, and logging tests are optional so the tool remains safe on any network.'
    $note.TextWrapping = 'Wrap'

    $buttonPanel = [StackPanel]::new()
    $buttonPanel.Orientation = 'Horizontal'
    $buttonPanel.Spacing = 12

    $runButton = [Button]::new()
    $runButton.Content = 'Run Assessment'
    $runButton.Style = [Application]::Current.Resources['AccentButtonStyle']

    $resultTitle = [TextBlock]::new()
    $resultTitle.Text = 'Readiness Summary'
    $resultTitle.Style = [Application]::Current.Resources['SubtitleTextBlockStyle']

    $resultBox = [TextBox]::new()
    $resultBox.AcceptsReturn = $true
    $resultBox.TextWrapping = 'Wrap'
    $resultBox.IsReadOnly = $true
    $resultBox.MinHeight = 360
    $resultBox.PlaceholderText = 'Run the readiness assessment to view results.'

    $runState = @{
        ToolManifest       = $toolManifest
        ToolWindow         = $toolWindow
        ResultBox          = $resultBox
        SqlConnectionBox   = $sqlConnectionBox
        ExchangeCheckBox   = $exchangeCheckBox
        SqlCheckBox        = $sqlCheckBox
        LoggingCheckBox    = $loggingCheckBox
        SaveValuesCheckBox = $saveValuesCheckBox
    }

    $runCallback = [EventCallback]::new()
    $runCallback.ArgumentList = $runState
    $runCallback.ScriptBlock = {
        param($state, $sender, $e)

        $savedValues = @{
            SqlConnectionString = $state.SqlConnectionBox.Text
            RunExchangeTest     = [bool]($state.ExchangeCheckBox.IsChecked -eq $true)
            RunSqlTest          = [bool]($state.SqlCheckBox.IsChecked -eq $true)
            RunLoggingTest      = [bool]($state.LoggingCheckBox.IsChecked -eq $true)
        }

        Save-PacToolConfig -ConfigPath $state.ToolManifest.configPath -SavedValues $savedValues -SaveValuesEnabled ([bool]($state.SaveValuesCheckBox.IsChecked -eq $true))

        try {
            $invokeParameters = @{
                SqlConnectionString = $state.SqlConnectionBox.Text
                RunExchangeTest     = [bool]($state.ExchangeCheckBox.IsChecked -eq $true)
                RunSqlTest          = [bool]($state.SqlCheckBox.IsChecked -eq $true)
                RunLoggingTest      = [bool]($state.LoggingCheckBox.IsChecked -eq $true)
            }

            $result = & $state.ToolManifest.scriptPath @invokeParameters
            $state.ResultBox.Text = Format-PacSessionReadinessResultText -Result $result
        }
        catch {
            $state.ResultBox.Text = ''
            Show-PacDialog -Title 'PAC Session Readiness Center failed' -Content $_.Exception.Message -Owner $state.ToolWindow
        }
    }
    $runButton.AddClick($runCallback)

    $buttonPanel.Children.Add($runButton)

    $panel.Children.Add($title)
    $panel.Children.Add($description)
    $panel.Children.Add($sqlConnectionBox)
    $panel.Children.Add($exchangeCheckBox)
    $panel.Children.Add($sqlCheckBox)
    $panel.Children.Add($loggingCheckBox)
    $panel.Children.Add($saveValuesCheckBox)
    $panel.Children.Add($saveValuesNote)
    $panel.Children.Add($note)
    $panel.Children.Add($buttonPanel)
    $panel.Children.Add($resultTitle)
    $panel.Children.Add($resultBox)

    Set-PacChildWindowContent -Window $toolWindow -Content $panel -WrapInScrollViewer
    $toolWindow.Activate()
}

function Get-PacSessionReadinessPage {
    param([hashtable]$Context)

    $toolManifest = Get-PacToolManifest -RootPath $Context.RootPath -ManifestPath 'Tools/PAC Session Readiness Center/tool.json'

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
            Glyph      = [char]0xE946
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
            $text.Text = 'Assess PAC runtime, authentication, module, and environment readiness before launching enterprise workflows.'
            $text.TextWrapping = 'Wrap'
            $text.Style = $pageContext.Resources['BodyTextBlockStyle']

            $button = [Button]::new()
            $button.Content = 'Open Readiness Center'
            $button.Style = $pageContext.Resources['AccentButtonStyle']

            $openToolCallback = [EventCallback]::new()
            $openToolCallback.ScriptBlock = {
                Show-PacSessionReadinessWindow
            }
            $button.AddClick($openToolCallback)

            $panel.Children.Add($title)
            $panel.Children.Add($text)
            $panel.Children.Add($button)

            $page.Content = $panel
        }
    }
}