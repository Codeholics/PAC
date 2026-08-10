$FunctionScriptPath = ''
$FunctionName = ''
$FunctionParameters = @{
    UserName  = ''
    CredsPath = ''
}

if ([string]::IsNullOrWhiteSpace($FunctionScriptPath)) {
    return [pscustomobject]@{
        Status  = 'Error'
        Message = 'Set FunctionScriptPath at the top of the probe script before using it in PAC.'
    }
}

if ([string]::IsNullOrWhiteSpace($FunctionName)) {
    return [pscustomobject]@{
        Status  = 'Error'
        Message = 'Set FunctionName at the top of the probe script before using it in PAC.'
    }
}

if (-not (Test-Path -LiteralPath $FunctionScriptPath)) {
    return [pscustomobject]@{
        Status  = 'Error'
        Message = "Function script was not found: $FunctionScriptPath"
    }
}

try {
    . $FunctionScriptPath
}
catch {
    return [pscustomobject]@{
        Status  = 'Error'
        Message = "Failed to load function script: $($_.Exception.Message)"
    }
}

$command = Get-Command $FunctionName -ErrorAction SilentlyContinue
if (-not $command) {
    return [pscustomobject]@{
        Status  = 'Error'
        Message = "The function '$FunctionName' was not found after loading $FunctionScriptPath"
    }
}

try {
    & $FunctionName @FunctionParameters | Out-Null

    $connectionInfo = @(Get-ConnectionInformation -ErrorAction Stop)
    if ($connectionInfo.Count -gt 0) {
        return [pscustomobject]@{
            Status  = 'Ready'
            Message = 'Exchange Online connection succeeded and Get-ConnectionInformation reported an active session.'
        }
    }

    return [pscustomobject]@{
        Status  = 'Unavailable'
        Message = 'The function ran, but Get-ConnectionInformation did not report an active Exchange Online session.'
    }
}
catch {
    return [pscustomobject]@{
        Status  = 'Error'
        Message = $_.Exception.Message
    }
}
