#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$manifestPath = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/TaffarelJr.GitHub.Account.psd1'
$module = Import-Module $manifestPath -Force -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Act - account names
$acceptedUsers = @(& $module {
        Assert-GitHubAccountName -User 'octocat'
        Assert-GitHubAccountName -User 'my-name_1'
        Assert-GitHubAccountName -User 'Name.With.Dots'
    })

# Assert
Assert-Equal -Expected @($true, $true, $true) -Actual $acceptedUsers -Message 'A login passes, answering $true'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - shapes that are no login: gh would take a dash-led one as a flag, the rest as no account it holds
$refusedUsers = @(
    '', ' ', 'two words', "me`t", "me$([char]0x00A0)x", "me$([char]0x200B)", "me$([char]0x2028)"
    '--hostname', '-me', 'a/b', 'a\b', 'a:b', 'user@x', 'a?b', 'a#b', 'gh*'
)

# Act / Assert
foreach ($refused in $refusedUsers) {
    $shown = [WildcardPattern]::Escape($refused)
    $pattern = "'$shown' is not an account name: give the login alone*leave -User out for the active account."
    Assert-Throws -ScriptBlock {
        & $module { Assert-GitHubAccountName -User $args[0] } $refused
    } -MessageLike $pattern `
        -Message "The account name '$refused' is refused"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - hosts are Core's to check
Assert-Throws -ScriptBlock {
    & $module { Assert-GitHubAccountName -Hostname 'github.com' }
} -MessageLike "*parameter cannot be found*'Hostname'*" `
    -Message 'There is no -Hostname: Assert-GitHubHostname checks hosts'

exit (Complete-TestRun)
