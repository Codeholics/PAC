function Register-PacPages {
    param([hashtable]$Context)

    return @(
        Get-HomePage -Context $Context
        Get-CompressDirectoryPage -Context $Context
        Get-GoogleMapsUrlPage -Context $Context
        Get-RegexExtractorPage -Context $Context
        Get-TextToSpeechPage -Context $Context
        Get-CSVToJSONPage -Context $Context
        # Add future pages here
    )
}
