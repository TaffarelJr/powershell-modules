#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values, and the text gh is given for each
$cases = @(
    @{ Value = $null; Expected = 'null'; Message = '$null is null' }
    @{ Value = $true; Expected = 'true'; Message = 'A bool is lower case' }
    @{ Value = [switch]$false; Expected = 'false'; Message = 'and so is a switch' }
    @{
        Value = [datetime]::new(2026, 1, 2, 3, 4, 5, [DateTimeKind]::Utc)
        Expected = '2026-01-02T03:04:05.0000000Z'
        Message = 'A date is ISO 8601'
    }
    @{
        Value = [DateTimeOffset]::new(2026, 1, 2, 3, 4, 5, [TimeSpan]::FromHours(2))
        Expected = '2026-01-02T03:04:05.0000000+02:00'
        Message = 'and so is a date with an offset'
    }
    @{ Value = 'text'; Expected = 'text'; Message = 'A string is itself' }
    @{ Value = 42; Expected = '42'; Message = 'A number is its text' }
    @{ Value = [uri]'https://x/'; Expected = 'https://x/'; Message = 'and so is a URI' }
)

# Act / Assert
foreach ($case in $cases) {
    $text = & $module { param($v) Format-GitHubFieldValue -Name 'f' -Value $v } $case.Value
    Assert-Equal -Expected $case.Expected -Actual $text -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - an object gh's fields cannot express
Assert-Throws -ScriptBlock {
    & $module { Format-GitHubFieldValue -Name 'owner' -Value ([PSCustomObject]@{ login = 'o' }) }
} -MessageLike "*Field 'owner' holds a PSCustomObject, which gh's fields cannot express - send it with -Body.*" `
    -Message 'An object throws instead of being sent as its type name'

exit (Complete-TestRun)
