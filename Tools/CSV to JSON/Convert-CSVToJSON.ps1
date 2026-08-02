param(
    [Parameter(Mandatory)]
    [string]$CsvText,

    [Parameter(Mandatory)]
    [ValidateSet('array','objects')]
    [string]$Mode
)

#function
function Convert-CsvToJSON {
    param(
        [Parameter(Mandatory)]
        [string]$CsvText,

        [Parameter(Mandatory)]
        [ValidateSet('array','objects')]
        [string]$Mode
    )

    # Convert CSV text to objects
    $csv = $CsvText | ConvertFrom-Csv

    switch ($Mode) {
        'array' {
            # Return JSON array of objects
            $json = $csv | ConvertTo-Json -Depth 10
        }
        'objects' {
            # Return JSON object keyed by first column
            $firstColumn = ($csv | Get-Member -MemberType NoteProperty)[0].Name
            $hash = @{}

            foreach ($row in $csv) {
                $key = $row.$firstColumn
                $hash[$key] = $row
            }

            $json = $hash | ConvertTo-Json -Depth 10
        }
    }

    return $json
}

if ($PSBoundParameters.Count -gt 0) {
    Convert-CsvToJSON @PSBoundParameters
}
