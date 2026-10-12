#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values, and the CSV field gh must be given for each
$cases = @(
    @{ Given = 'bug'; Expected = 'bug'; Message = 'A plain value is returned unchanged' }
    @{ Given = 'good first issue'; Expected = 'good first issue'; Message = 'and so is one with spaces' }
    @{ Given = ''; Expected = ''; Message = 'and an empty one' }
    @{
        Given = 'bug, urgent'
        Expected = '"bug, urgent"'
        Message = 'A value with a comma is quoted, so it stays one value'
    }
    @{
        Given = 'say "hi"'
        Expected = '"say ""hi"""'
        Message = 'A value with a double quote is quoted, with the quote doubled'
    }
    @{ Given = "two`nlines"; Expected = "`"two`nlines`""; Message = 'A value with a line feed is quoted' }
    @{ Given = "two`rlines"; Expected = "`"two`rlines`""; Message = 'and so is one with a carriage return' }
)

# Act / Assert
foreach ($case in $cases) {
    Assert-Equal -Expected $case.Expected -Actual (ConvertTo-GitHubCsvField -Value $case.Given) -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Act - several values at once
$fields = @(ConvertTo-GitHubCsvField -Value 'a', 'b,c', 'd')

# Assert
Assert-Equal -Expected @('a', '"b,c"', 'd') -Actual $fields -Message 'Each value comes back as its own field, in order'

exit (Complete-TestRun)
