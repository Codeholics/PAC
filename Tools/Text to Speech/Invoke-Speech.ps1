param(
    [string]$Text,
    [int]$Speed,
    [int]$Volume,
    [string]$Voice,
    [switch]$Generate,
    [switch]$Resume
)

$script:SpeechToolRoot = $PSScriptRoot

<#
.SYNOPSIS
    Speaks the specified text using the default system settings.

.DESCRIPTION
    The `Invoke-Speech` function speaks the specified text using the default system settings. 
    You can specify the speed, volume, and voice of the speech. Additionally, you can generate a standalone PowerShell script 
    that reproduces the speech settings or return the current speech settings as a hash table.

.PARAMETER Text
    The text to speak.

.PARAMETER Speed
    The speed of the speech, in words per minute. Higher values result in faster speech.

.PARAMETER Volume
    The volume of the speech, as a percentage of the maximum volume (0 to 100).

.PARAMETER Voice
    The name of the voice to use for the speech. Use `Get-InstalledVoices` to list available voices.

.PARAMETER Generate
    Generates a standalone PowerShell script (`My_Speech_Script.ps1`) on the desktop that reproduces the speech settings.
    The script includes all specified parameters (e.g., speed, volume, voice, and text) and can be executed independently.

.PARAMETER Resume
    Returns a hash table of the current speech settings, including the text, speed, volume, and voice. 
    This is useful for debugging or saving the configuration for later use.

.EXAMPLE
    Invoke-Speech -Text "Hello, world!"

    This example speaks the text "Hello, world!" using the default system settings.

.EXAMPLE
    Invoke-Speech -Text "Hello, world!" -Speed 200 -Volume 50 -Voice "Microsoft David Desktop"

    This example speaks the text "Hello, world!" using the Microsoft David Desktop voice, at a speed of 200 words per minute and a volume of 50%.

.EXAMPLE
    Invoke-Speech -Text "Hello, world!" -Generate

    This example speaks the text "Hello, world!" and generates a standalone PowerShell script (`My_Speech_Script.ps1`) on the desktop 
    that reproduces the speech settings.

.EXAMPLE
    Invoke-Speech -Text "Hello, world!" -Resume

    This example speaks the text "Hello, world!" and returns a hash table of the current speech settings.

.NOTES
    Author: Codeholics (https://github.com/Codeholics) - Eric Reis (https://github.com/EReis0/)
    Version: 1.2
    Date: 4/2025

.LINK
    https://github.com/EReis0/PowerShell-Samples/
#>
function Invoke-Speech {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true, position=1)]		
        [string] $Text,				
        [Parameter(Mandatory=$False,Position=1)]
        [int] $Speed,
        [Parameter(Mandatory=$False,Position=1)]
        [int] $Volume,	
        [Parameter(Mandatory=$False,Position=1)]
        [string] $Voice,		
        [Parameter(Mandatory=$False,Position=1)]		
        [switch] $Generate,	
        [Parameter(Mandatory=$False,Position=1)]		
        [switch] $Resume				
    )
    
    Try {						
        Add-Type -AssemblyName System.speech
        $Global:Talk = New-Object System.Speech.Synthesis.SpeechSynthesizer
        If ($Voice) {
            $Talk.SelectVoice($Voice)
        }
    } Catch {
        throw "Cannot load the System Speech assembly: $($_.Exception.Message)"
    }		
    

    if ($PSBoundParameters.ContainsKey('Speed')) {
        $Talk.Rate = $Speed
    }
        
    if ($PSBoundParameters.ContainsKey('Volume')) {
        $Talk.Volume = $Volume
    }
        
    $Talk.Speak($Text)

    If ($Generate) {
        $outputPath = Join-Path -Path $script:SpeechToolRoot -ChildPath 'output'
        if (-not (Test-Path -LiteralPath $outputPath)) {
            New-Item -Path $outputPath -ItemType Directory | Out-Null
        }

        $Script_File = Join-Path -Path $outputPath -ChildPath "My_Speech_Script.ps1"
        New-Item -Path $Script_File -Type File -Force | Out-Null
        Add-Content -LiteralPath $Script_File "#Load assembly"	
        Add-Content -LiteralPath $Script_File 'Add-Type -AssemblyName System.speech'
        Add-Content -LiteralPath $Script_File '$Talk = New-Object System.Speech.Synthesis.SpeechSynthesizer'

        If ($Voice) {
            $escapedVoice = $Voice -replace "'", "''"
            Add-Content -LiteralPath $Script_File "" 
            Add-Content -LiteralPath $Script_File "# Set the selected voice"
            Add-Content -LiteralPath $Script_File ("`$Talk.SelectVoice('{0}')" -f $escapedVoice)
        }

        if ($PSBoundParameters.ContainsKey('Speed')) {
            Add-Content -LiteralPath $Script_File "" 
            Add-Content -LiteralPath $Script_File "# Set the speed value"
            Add-Content -LiteralPath $Script_File ("`$Talk.Rate = {0}" -f $Speed)
        }

        if ($PSBoundParameters.ContainsKey('Volume')) {
            Add-Content -LiteralPath $Script_File "" 
            Add-Content -LiteralPath $Script_File "# Set the volume value"
            Add-Content -LiteralPath $Script_File ("`$Talk.Volume = {0}" -f $Volume)
        }

        $escapedText = $Text -replace "'", "''"
        Add-Content -LiteralPath $Script_File "" 
        Add-Content -LiteralPath $Script_File "# Set the text to speak"
        Add-Content -LiteralPath $Script_File ("`$Talk.Speak('{0}')" -f $escapedText)
    }

    If ($Resume) {
        $ResumeOutput = @{
            "Volume" = $Talk.Volume
            "Speed" = $Talk.Rate
            "Voice" = $Talk.Voice.Name
            "Text" = $Text
            "Generate script" = $Generate
        }
        $ResumeOutput
    }
    # New-Alias -Name "speak" -Value "Invoke-Speech"
    # Set-Alias -Name "speak" -Value "Invoke-Speech"
}  # Invoke-Speech -Text "Hello"

if ($PSBoundParameters.Count -gt 0) {
    Invoke-Speech @PSBoundParameters
}
