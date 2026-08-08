param(
    [string]$Identity,
    [string]$Title,
    [string]$Manager,
    [string]$Company,
    [string]$Division,
    [string]$Group,
    [string[]]$SelectedColumns,
    [switch]$UseSampleData,
    [switch]$IncludeMailbox,
    [switch]$IncludeSqlData,
    [switch]$ExportResults,
    [string]$ExportPath,
    [string]$SqlConnectionString
)

function Get-EnterpriseUserAuditSampleData {
    return @(
        [pscustomobject]@{
            DisplayName       = 'Ada Lovelace'
            SamAccountName    = 'ada.lovelace'
            UserPrincipalName = 'ada.lovelace@contoso.com'
            Title             = 'Senior Engineer'
            Department        = 'Platform Engineering'
            Company           = 'Contoso'
            Division          = 'Technology'
            Manager           = 'Grace Hopper'
            Enabled           = $true
            GroupMatch        = 'VPN Users; Engineering Leads'
            MailboxSize       = '1.20 GB'
            ForwardingAddress = ''
            EmploymentStatus  = 'Active'
            Source            = 'SampleData'
        }
        [pscustomobject]@{
            DisplayName       = 'Katherine Johnson'
            SamAccountName    = 'katherine.johnson'
            UserPrincipalName = 'katherine.johnson@contoso.com'
            Title             = 'Principal Analyst'
            Department        = 'Operations Research'
            Company           = 'Contoso'
            Division          = 'Finance'
            Manager           = 'Dorothy Vaughan'
            Enabled           = $true
            GroupMatch        = 'Finance Reporting'
            MailboxSize       = '842 MB'
            ForwardingAddress = 'finance-archive@contoso.com'
            EmploymentStatus  = 'Active'
            Source            = 'SampleData'
        }
        [pscustomobject]@{
            DisplayName       = 'Alan Turing'
            SamAccountName    = 'alan.turing'
            UserPrincipalName = 'alan.turing@contoso.com'
            Title             = 'Security Architect'
            Department        = 'Information Security'
            Company           = 'Contoso'
            Division          = 'Technology'
            Manager           = 'Grace Hopper'
            Enabled           = $false
            GroupMatch        = 'PAC_Admins; Security Operations'
            MailboxSize       = '2.04 GB'
            ForwardingAddress = ''
            EmploymentStatus  = 'Leave'
            Source            = 'SampleData'
        }
    )
}

function Test-EnterpriseUserAuditValue {
    param(
        [AllowNull()]
        $ActualValue,

        [string]$ExpectedValue
    )

    if ([string]::IsNullOrWhiteSpace($ExpectedValue)) {
        return $true
    }

    return ([string]$ActualValue) -like ('*{0}*' -f $ExpectedValue)
}

function Get-EnterpriseUserAuditModuleStatus {
    $moduleStatus = [ordered]@{}
    foreach ($moduleName in 'ActiveDirectory', 'ExchangeOnlineManagement', 'SqlServer', 'ImportExcel', 'PSLogging') {
        $moduleStatus[$moduleName] = if (Get-Module -ListAvailable -Name $moduleName) { 'Available' } else { 'Missing' }
    }

    return [pscustomobject]$moduleStatus
}

function Get-EnterpriseUserAuditAdFilter {
    param(
        [string]$Identity,
        [string]$Title,
        [string]$Manager,
        [string]$Company,
        [string]$Division
    )

    $clauses = [System.Collections.ArrayList]::new()

    if (-not [string]::IsNullOrWhiteSpace($Identity)) {
        $escapedIdentity = $Identity.Replace("'", "''")
        [void]$clauses.Add("(DisplayName -like '*$escapedIdentity*' -or SamAccountName -like '*$escapedIdentity*' -or UserPrincipalName -like '*$escapedIdentity*')")
    }

    foreach ($filterSpec in @(
        @{ Name = 'Title'; Value = $Title },
        @{ Name = 'Manager'; Value = $Manager },
        @{ Name = 'Company'; Value = $Company },
        @{ Name = 'Division'; Value = $Division }
    )) {
        if (-not [string]::IsNullOrWhiteSpace($filterSpec.Value)) {
            $escapedValue = $filterSpec.Value.Replace("'", "''")
            [void]$clauses.Add("($($filterSpec.Name) -like '*$escapedValue*')")
        }
    }

    if ($clauses.Count -eq 0) {
        return '*'
    }

    return ($clauses -join ' -and ')
}

function Get-EnterpriseUserAuditAdRecords {
    param(
        [string]$Identity,

        [string]$Title,

        [string]$Manager,

        [string]$Company,

        [string]$Division,

        [string]$Group,

        [switch]$IncludeMailbox,

        [switch]$IncludeSqlData,

        [string]$SqlConnectionString
    )

    $properties = @(
        'DisplayName',
        'SamAccountName',
        'UserPrincipalName',
        'Title',
        'Department',
        'Company',
        'Division',
        'Manager',
        'Enabled',
        'mail',
        'EmployeeID',
        'DistinguishedName'
    )

    $adFilter = Get-EnterpriseUserAuditAdFilter -Identity $Identity -Title $Title -Manager $Manager -Company $Company -Division $Division
    $memberLookup = $null
    $groupMembers = @()

    if (-not [string]::IsNullOrWhiteSpace($Group)) {
        try {
            $groupMembers = @(Get-ADGroupMember -Identity $Group -Recursive -ErrorAction Stop | Where-Object objectClass -eq 'user')
            $memberLookup = @{}
            foreach ($member in $groupMembers) {
                if ($member.PSObject.Properties.Name -contains 'DistinguishedName' -and $member.DistinguishedName) {
                    $memberLookup[$member.DistinguishedName] = $true
                }

                if ($member.PSObject.Properties.Name -contains 'SamAccountName' -and $member.SamAccountName) {
                    $memberLookup[$member.SamAccountName] = $true
                }

                if ($member.Name) {
                    $memberLookup[$member.Name] = $true
                }
            }
        }
        catch {
            Write-Warning ("Unable to resolve group '{0}': {1}" -f $Group, $_.Exception.Message)
            return @()
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Group) -and $adFilter -eq '*') {
        $resolvedUsers = foreach ($member in $groupMembers) {
            $memberIdentity = $null

            if ($member.PSObject.Properties.Name -contains 'DistinguishedName' -and $member.DistinguishedName) {
                $memberIdentity = $member.DistinguishedName
            }
            elseif ($member.PSObject.Properties.Name -contains 'SamAccountName' -and $member.SamAccountName) {
                $memberIdentity = $member.SamAccountName
            }

            if (-not [string]::IsNullOrWhiteSpace($memberIdentity)) {
                Get-ADUser -Identity $memberIdentity -Properties $properties -ErrorAction SilentlyContinue
            }
        }
        $users = @($resolvedUsers | Where-Object { $null -ne $_ })
    }
    else {
        $users = @(Get-ADUser -Filter $adFilter -Properties $properties)
    }

    if ($memberLookup) {
        $users = @($users | Where-Object {
            $memberLookup.ContainsKey($_.DistinguishedName) -or
            $memberLookup.ContainsKey($_.SamAccountName) -or
            $memberLookup.ContainsKey($_.Name)
        })
    }

    $mailboxCommand = if ($IncludeMailbox) { Get-Command Get-Mailbox -ErrorAction SilentlyContinue } else { $null }
    $mailboxStatsCommand = if ($IncludeMailbox) { Get-Command Get-MailboxStatistics -ErrorAction SilentlyContinue } else { $null }
    $sqlCommand = if ($IncludeSqlData -and -not [string]::IsNullOrWhiteSpace($SqlConnectionString)) { Get-Command Invoke-Sqlcmd -ErrorAction SilentlyContinue } else { $null }

    $records = foreach ($user in $users) {
        $record = [ordered]@{
            DisplayName       = $user.DisplayName
            SamAccountName    = $user.SamAccountName
            UserPrincipalName = $user.UserPrincipalName
            Title             = $user.Title
            Department        = $user.Department
            Company           = $user.Company
            Division          = $user.Division
            Manager           = $user.Manager
            Enabled           = $user.Enabled
            GroupMatch        = if ([string]::IsNullOrWhiteSpace($Group)) { '' } else { $Group }
            MailboxSize       = ''
            ForwardingAddress = ''
            EmploymentStatus  = ''
            Source            = 'ActiveDirectory'
        }

        if ($mailboxCommand) {
            try {
                $mailbox = Get-Mailbox -Identity $user.UserPrincipalName -ErrorAction Stop
                if ($mailboxStatsCommand) {
                    $mailboxStats = Get-MailboxStatistics -Identity $user.UserPrincipalName -ErrorAction SilentlyContinue
                    if ($mailboxStats -and $mailboxStats.PSObject.Properties.Name -contains 'TotalItemSize') {
                        $record.MailboxSize = [string]$mailboxStats.TotalItemSize
                    }
                }

                if ($mailbox -and $mailbox.PSObject.Properties.Name -contains 'ForwardingSmtpAddress') {
                    $record.ForwardingAddress = [string]$mailbox.ForwardingSmtpAddress
                }
            }
            catch {
                Write-Verbose ("Exchange enrichment skipped for {0}: {1}" -f $user.SamAccountName, $_.Exception.Message)
            }
        }

        if ($sqlCommand -and $user.EmployeeID) {
            try {
                $query = @"
SELECT TOP 1 Department, EmploymentStatus
FROM HR
WHERE EmployeeID = '$($user.EmployeeID)'
"@

                $sqlRecord = Invoke-Sqlcmd -ConnectionString $SqlConnectionString -Query $query -ErrorAction Stop | Select-Object -First 1
                if ($sqlRecord) {
                    if ($sqlRecord.PSObject.Properties.Name -contains 'Department' -and $sqlRecord.Department) {
                        $record.Department = $sqlRecord.Department
                    }

                    if ($sqlRecord.PSObject.Properties.Name -contains 'EmploymentStatus' -and $sqlRecord.EmploymentStatus) {
                        $record.EmploymentStatus = $sqlRecord.EmploymentStatus
                    }
                }
            }
            catch {
                Write-Verbose ("SQL enrichment skipped for {0}: {1}" -f $user.SamAccountName, $_.Exception.Message)
            }
        }

        [pscustomobject]$record
    }

    return @($records)
}

function Export-EnterpriseUserAuditRecords {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IEnumerable]$Records,

        [Parameter(Mandatory)]
        [string]$ExportPath,

        [string[]]$SelectedColumns
    )

    $recordsArray = @($Records)
    if ($recordsArray.Count -eq 0) {
        return ''
    }

    $targetPath = $ExportPath
    if ([string]::IsNullOrWhiteSpace($targetPath)) {
        $targetDirectory = Join-Path $PSScriptRoot 'output'
        $targetPath = Join-Path $targetDirectory ('EnterpriseUserAudit_{0}.xlsx' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    }

    $targetDirectory = Split-Path -Path $targetPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($targetDirectory) -and -not (Test-Path -LiteralPath $targetDirectory)) {
        New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
    }

    $exportColumns = @($SelectedColumns | Where-Object { $recordsArray[0].PSObject.Properties.Name -contains $_ })
    if ($exportColumns.Count -eq 0) {
        $exportColumns = @($recordsArray[0].PSObject.Properties.Name)
    }

    if (Get-Command Export-Excel -ErrorAction SilentlyContinue) {
        $recordsArray | Select-Object -Property $exportColumns | Export-Excel -Path $targetPath -AutoSize -WorksheetName 'User Audit'
        return (Resolve-Path -LiteralPath $targetPath).Path
    }

    $csvPath = [System.IO.Path]::ChangeExtension($targetPath, '.csv')
    $recordsArray | Select-Object -Property $exportColumns | Export-Csv -Path $csvPath -NoTypeInformation
    return (Resolve-Path -LiteralPath $csvPath).Path
}

function Write-EnterpriseUserAuditLogEntry {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    if (Get-Command Write-PSLog -ErrorAction SilentlyContinue) {
        Write-PSLog -Message $Message -Level Info
    }
}

function Invoke-EnterpriseUserAudit {
    [CmdletBinding()]
    param(
        [string]$Identity,
        [string]$Title,
        [string]$Manager,
        [string]$Company,
        [string]$Division,
        [string]$Group,
        [string[]]$SelectedColumns = @('DisplayName', 'SamAccountName', 'UserPrincipalName', 'Department', 'Enabled', 'Source'),
        [switch]$UseSampleData,
        [switch]$IncludeMailbox,
        [switch]$IncludeSqlData,
        [switch]$ExportResults,
        [string]$ExportPath,
        [string]$SqlConnectionString
    )

    $moduleStatus = Get-EnterpriseUserAuditModuleStatus
    $records = @()
    $source = 'Unavailable'

    if ($UseSampleData) {
        $records = Get-EnterpriseUserAuditSampleData
        $source = 'SampleData'
    }
    elseif ($moduleStatus.ActiveDirectory -eq 'Available') {
        $records = Get-EnterpriseUserAuditAdRecords -Identity $Identity -Title $Title -Manager $Manager -Company $Company -Division $Division -Group $Group -IncludeMailbox:$IncludeMailbox -IncludeSqlData:$IncludeSqlData -SqlConnectionString $SqlConnectionString
        $source = 'ActiveDirectory'
    }

    $records = @($records | Where-Object {
        (Test-EnterpriseUserAuditValue -ActualValue $_.DisplayName -ExpectedValue $Identity) -or
        (Test-EnterpriseUserAuditValue -ActualValue $_.SamAccountName -ExpectedValue $Identity) -or
        (Test-EnterpriseUserAuditValue -ActualValue $_.UserPrincipalName -ExpectedValue $Identity)
    })

    $records = @($records | Where-Object {
        (Test-EnterpriseUserAuditValue -ActualValue $_.Title -ExpectedValue $Title) -and
        (Test-EnterpriseUserAuditValue -ActualValue $_.Manager -ExpectedValue $Manager) -and
        (Test-EnterpriseUserAuditValue -ActualValue $_.Company -ExpectedValue $Company) -and
        (Test-EnterpriseUserAuditValue -ActualValue $_.Division -ExpectedValue $Division) -and
        (Test-EnterpriseUserAuditValue -ActualValue $_.GroupMatch -ExpectedValue $Group)
    })

    $resolvedExportPath = ''
    if ($ExportResults) {
        $resolvedExportPath = Export-EnterpriseUserAuditRecords -Records $records -ExportPath $ExportPath -SelectedColumns $SelectedColumns
    }

    Write-EnterpriseUserAuditLogEntry -Message ("Enterprise User Audit completed from {0} with {1} record(s)." -f $source, $records.Count)

    return [pscustomobject]@{
        Source       = $source
        Records      = @($records)
        Count        = @($records).Count
        ExportPath   = $resolvedExportPath
        ModuleStatus = $moduleStatus
    }
}

if ($PSBoundParameters.Count -gt 0) {
    Invoke-EnterpriseUserAudit @PSBoundParameters
}