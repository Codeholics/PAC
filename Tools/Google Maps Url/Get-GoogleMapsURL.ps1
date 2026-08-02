param (
    [string]$Address
)
<#
.SYNOPSIS
    Generates a Google Maps URL for a given address.

.DESCRIPTION
    The `Get-GoogleMapsURL` function takes an address as input, encodes it for use in a URL, and generates a Google Maps URL.

.PARAMETER Address
    The address for which the Google Maps URL should be generated. This parameter is mandatory.

.EXAMPLE
    PS> Get-GoogleMapsURL -Address "200 S Executive Dr., Suite 1013, Brookfield, WI 53005"
    https://www.google.com/maps?q=200+S+Executive+Dr.%2C+Suite+1013%2C+Brookfield%2C+WI+53005

    This example generates a Google Maps URL for the specified address.

.EXAMPLE
    PS> Get-GoogleMapsURL -Address "1600 Amphitheatre Parkway, Mountain View, CA"
    https://www.google.com/maps?q=1600+Amphitheatre+Parkway%2C+Mountain+View%2C+CA

    This example generates a Google Maps URL for the Google headquarters address.

.NOTES
    Author: Codeholics (https://github.com/Codeholics) - Eric Reis (https://github.com/EReis0/)
    Version: 1.0
    Date: 03/30/2025
#>
function Get-GoogleMapsURL {
    param (
        [string][Parameter(Mandatory=$true)]$Address
    )

    if ([string]::IsNullOrWhiteSpace($Address)) {
        throw 'Address is null or empty. Please provide a valid address.'
    }

    $webEncode = [System.Net.WebUtility]::UrlEncode($Address)
    return "https://www.google.com/maps?q=$webEncode"
}

if ($PSBoundParameters.Count -gt 0) {
    Get-GoogleMapsURL @PSBoundParameters
}
