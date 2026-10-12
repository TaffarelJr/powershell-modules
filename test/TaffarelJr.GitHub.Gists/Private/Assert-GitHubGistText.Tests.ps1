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
# Arrange - the control characters text holds
$texts = @(
    @{ Text = "a`tb"; Message = 'A tab is text' }
    @{ Text = "a`nb`r`n"; Message = 'and so are line feeds and carriage returns' }
    @{ Text = "a`fb"; Message = 'and a form feed' }
    @{ Text = "`e[31mred`e[0m"; Message = 'and the escape of a terminal colour' }
    @{ Text = " `n x"; Message = 'and whitespace around text' }
)

# Act / Assert
foreach ($case in $texts) {
    $output = @(& $module { param($t) Assert-GitHubGistText -Text $t -Source '-Content' } $case.Text)
    Assert-Equal -Expected 0 -Actual $output.Count -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the control characters only binary data holds
$binary = @(
    @{ Text = "a`0b"; Message = 'A NUL is binary' }
    @{ Text = "a`vb"; Message = 'and so is a vertical tab' }
    @{ Text = "a$([char]0x1F)b"; Message = 'and a unit separator' }
)

# Act / Assert
foreach ($case in $binary) {
    Assert-Throws -ScriptBlock {
        & $module { param($t) Assert-GitHubGistText -Text $t -Source "'x.bin'" } $case.Text
    } -MessageLike "'x.bin' holds binary data, and a gist holds text only." -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - content GitHub refuses as no content at all
$blank = @(
    @{ Text = ''; Message = 'Nothing at all is refused' }
    @{ Text = '   '; Message = 'and so are spaces alone' }
    @{ Text = "`t`r`n `n"; Message = 'and tabs and line breaks alone' }
)

# Act / Assert
foreach ($case in $blank) {
    Assert-Throws -ScriptBlock {
        & $module { param($t) Assert-GitHubGistText -Text $t -Source '-Content' } $case.Text
    } -MessageLike '-Content is empty or only whitespace, and GitHub refuses a gist file with no content.' `
        -Message $case.Message
}

exit (Complete-TestRun)
