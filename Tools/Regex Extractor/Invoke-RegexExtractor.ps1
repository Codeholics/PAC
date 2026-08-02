param(
    [string]$Text,
    [string]$Pattern,
    [ValidateSet('matches','groups','unique')]
    [string]$Mode
)

function Invoke-RegexExtractor {
    param(
        [Parameter(Mandatory)]
        [string]$Text,
        [Parameter(Mandatory)]
        [string]$Pattern,
        [Parameter(Mandatory)]
        [ValidateSet('matches','groups','unique')]
        [string]$Mode
    )

    try {
        $matchCollection = [regex]::Matches($Text, $Pattern)
    }
    catch {
        throw "Invalid regex pattern '$Pattern': $($_.Exception.Message)"
    }

    switch ($Mode) {
        'matches' {
            $result = $matchCollection.Value
        }

        'groups' {
            $result = foreach ($m in $matchCollection) {
                if ($m.Groups.Count -gt 1) {
                    $m.Groups[1].Value
                }
            }
        }

        'unique' {
            $result = ($matchCollection.Value | Select-Object -Unique)
        }
    }

    if (-not $result) {
        $result = @()
    }

    return ($result | ConvertTo-Json -Depth 10)
}

if ($PSBoundParameters.Count -gt 0) {
    Invoke-RegexExtractor @PSBoundParameters
}
