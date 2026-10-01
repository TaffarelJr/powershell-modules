#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange - content, and the line ending it should be read as
$cases = @(
    @{
        Content  = "a`r`nb`r`n"
        Expected = "`r`n"
        Message  = 'CRLF content is detected as CRLF'
    }
    @{
        Content  = "a`nb`n"
        Expected = "`n"
        Message  = 'LF-only content is detected as LF'
    }
    @{
        Content  = "a`nb`nc`nd`r`n"
        Expected = "`n"
        Message  = 'A single stray CRLF among many bare LFs does not turn the file into CRLF'
    }
    @{
        Content  = "a`r`nb`r`nc`r`nd`n"
        Expected = "`r`n"
        Message  = 'and a single stray LF among many CRLFs does not turn it into LF'
    }
    @{
        Content  = "a`r`nb`r`nc`nd"
        Expected = "`r`n"
        Message  = 'Two CRLFs outvote one LF, which they would not if each CRLF counted twice'
    }
    @{
        Content  = "a`nb`r`n"
        Expected = "`r`n"
        Message  = 'A tie of one of each is CRLF'
    }
    @{
        Content  = 'no newline here'
        Expected = [Environment]::NewLine
        Message  = 'Content with no line break falls back to the platform default'
    }
    @{
        Content  = ''
        Expected = [Environment]::NewLine
        Message  = 'Empty content falls back to the platform default too'
    }
)

foreach ($case in $cases) {
    # Act
    $ending = Get-LineEnding -Content $case.Content

    # Assert
    Assert-Equal -Expected $case.Expected -Actual $ending -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$positional = Get-LineEnding "a`nb`n"

# Assert
Assert-Equal -Expected "`n" -Actual $positional -Message 'The content can be given by position'

exit (Complete-TestRun)
