#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.PullRequests/TaffarelJr.GitHub.PullRequests.psd1') `
    -Force `
    -PassThru

$convert = {
    param($Value)
    ConvertTo-GitHubPullRequestListArgument -Name 'AddLabel' -Flag '--add-label' -Value $Value
}

#───────────────────────────────────────────────────────────────────────────────
# Act - names, one plain, one holding a comma, one holding a quote, one that is --
$arguments = @(& $module $convert @('bug', 'needs fix, soon', 'say "hi"', '--'))

# Assert
Assert-Equal -Expected @(
    '--add-label=bug'
    '--add-label="needs fix, soon"'
    '--add-label="say ""hi"""'
    '--add-label=--'
) -Actual $arguments -Message 'Each name is one --flag=field token, quoted as a CSV field where gh would split it'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - nothing to send
Assert-Equal -Expected 0 -Actual @(& $module $convert @()).Count -Message 'An empty list sends nothing'
Assert-Equal -Expected 0 -Actual @(& $module $convert $null).Count -Message 'and so does a list left out'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a blank name anywhere in the list
$message = '-AddLabel has a blank element, which would send --add-label= with nothing after it.' +
' Give names, or leave -AddLabel out.'
foreach ($blank in '', ' ', "`t", $null) {
    Assert-Throws -ScriptBlock {
        & $module $convert @('bug', $blank)
    } -MessageLike $message -Message 'A blank name throws, naming the parameter and the flag'
}

exit (Complete-TestRun)
