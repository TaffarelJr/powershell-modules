#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1') -Force `
    -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the control characters text holds, and the other text
$text = @(
    @{ Text = "a`tb"; Message = 'A tab is text' }
    @{ Text = "a`nb`r`n"; Message = 'and so are line feeds and carriage returns' }
    @{ Text = "a`fb"; Message = 'and a form feed' }
    @{ Text = "`e[31mred`e[0m"; Message = 'and the escape of a terminal colour' }
    @{ Text = "a$([char]0x85)b"; Message = 'and a C1 control, which UTF-8 holds in two bytes' }
    @{ Text = "é 漢字 😀"; Message = 'and characters far beyond ASCII' }
    @{ Text = ''; Message = 'and nothing at all' }
)

# Act / Assert
foreach ($case in $text) {
    $actual = & $module { param($t) Test-GitHubGistBinary -Text $t } $case.Text
    Assert-Equal -Expected $false -Actual $actual -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one control character from each end of each range only binary data holds
$binary = @(
    @{ Text = "a`0b"; Message = 'A NUL is binary' }
    @{ Text = "a$([char]0x08)b"; Message = 'and so is a backspace, the end of the first range' }
    @{ Text = "a`vb"; Message = 'and a vertical tab' }
    @{ Text = "a$([char]0x0E)b"; Message = 'and a shift out, the start of the second range' }
    @{ Text = "a$([char]0x1A)b"; Message = 'and a substitute, the end of it' }
    @{ Text = "a$([char]0x1C)b"; Message = 'and a file separator, the start of the third range' }
    @{ Text = "a$([char]0x1F)b"; Message = 'and a unit separator, the end of it' }
)

# Act / Assert
foreach ($case in $binary) {
    $actual = & $module { param($t) Test-GitHubGistBinary -Text $t } $case.Text
    Assert-Equal -Expected $true -Actual $actual -Message $case.Message
}

exit (Complete-TestRun)
