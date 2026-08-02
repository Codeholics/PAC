# PowerShell Automation Center

PowerShell WPF application that features all useful tools in one central location.

## Requirements

- Must work with PowerShell 7. If possible 5.1 compatibility is nice but not a requirement if it hinders the applications feature abilities.

### Configuration Files
- I prefer to use JSON as a configuration file that the application can import for settings, data, and file paths. I normally set a variable for the root directory but other than that, all paths and settings should be coming from the config.

### Application GUI Launch
- `.bat` script that changes the execution policy to bypass and then calls the application start file.

### Authentication
Allow Active Directory Authentication (When detected in environment, otherwise hide)
- With AD: Require authentication from active directory. We will need to capture the users SamAccountName, mail and additional AD details.
- With AD: User should have a specific security group `SAMPLE SECURITY GROUP` in order to be authenticated successfully.
- With AD: After being authenticated via Active Directory, the automation center will use a service account behind the scenes to execute scripts that require AD, Exchange, Azure, SQL permissions.
- No AD: First time login would require apps temp admin account. 
- With AD/No AD: We should keep a record of the users in either a SQLite db or a JSON file. We can use this for permissions and preferences.
- With No AD: Scripts with the Role "Account Management" should have their buttons to launch the individual scripts set to view only. AD Authentication is required.

Sample of Authentication Routes and Access

|AuthType|Authenticate|Requires Security Group|AD Scripts|Exchange Scripts|General Scripts|
|---|---|---|---|---|---|
|AD|Yes|`Account Managemet`|Yes|Yes|Yes|
|Local|Yes|-|No|No|Yes|

Sample of User Record for application

|id|username|displayname|emailaddress|theme|
|---|---|---|---|---|
|1|jdoe|John Doe|jdoe@sample.com|dark|

### PSLogging Integration

Import PSLogging and initiate logging like this

Start the log

```powershell
# Path to log directory
$logPath = "U:\"
$Version = "1.0.0"

# Create log file (and directory if necessary)
$logPath = Join-Path -Path $LogPath -ChildPath "$(Get-Date -UFormat '%Y')\$(Get-Date -UFormat '%Y-%m')\$(Get-Date -UFormat '%Y-%m-%d_%H%M%S').log"

if (!(Test-Path -Path (Split-Path -Parent $logPath))) {
   New-Item -Path (Split-Path -Parent $logPath) -ItemType Directory | Out-Null
}

if (!(Test-Path -Path $logPath)) {
   New-Item -Path $logPath -ItemType File | Out-Null
}

# Initialize the log
Start-Log -LogPath ($logPath | Split-Path -Parent) -LogName (Split-Path $logPath -Leaf) -ScriptVersion $Version
Write-LogInfo -LogPath $logPath -Message ' ' -ToScreen
Write-LogInfo -LogPath $logPath -Message "Initiating GetUserGroups script for [$($SamAccountName)]." -ToScreen
Write-LogInfo -LogPath $logPath -Message ' ' -ToScreen
```

Informational

```powershell
Write-LogInfo -LogPath $logPath -Message "[$(Get-Date)] Group memberships obtained for user [$($SamAccountName)]." -ToScreen
```

Warning

```Powershell
$Message = "[$(Get-Date)] No groups found for user [$($SamAccountName)]"
Write-LogWarning -LogPath $logPath -Message $Message -ToScreen
```

Errors

```powershell
$Message = "[$(Get-Date)] Failed to obtain user [$($SamAccountName)] group memberships: $($_.Exception.Message)"
Write-LogError -LogPath $logPath -Message $Message -ToScreen
```

Stop Logging

```powershell
Stop-Log -LogPath $logPath -NoExit
```

### Modules (Locally Stored)

While at work, some users may not have permissions to download and install modules. Because of this, we need to download the modules required for this project and store them inside the project.

`import-module $modulepath`

- Active Directory
- Exchange Management Online
- SQLsvr
- ImportExcel
- [PSLogging](https://www.powershellgallery.com/packages/PSLogging)
- AMTools
- [WinUIShell](https://www.powershellgallery.com/packages/WinUIShell) | [GitHub project page](https://github.com/mdgrs-mei/WinUIShell/)

### UI Framework

- WinUi3

## Nice to have

1. A setting that changes the app from light mode to dark mode. We would also need a way to save the last setting you chosen for this (maybe JSON)?
2. I way to register new scripts in the Automation center. This should basically integrate the new script into the suit and autoconfigure the automation center to include the new script. Something like:
```powershell
$Path = 'C:\Scripts\Get-DGReport.ps1'
$Cat = 'Exchange'
$Role = 'Account Management'
Register-NewScript -ScriptPath $Path -Category $Cat -Role $Role
```

