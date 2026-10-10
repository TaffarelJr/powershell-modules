#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the minimum: a name and a visibility
$fake = New-FakeGitHubCli -Output @('https://github.com/o/new')
try {
    # Act
    $url = New-GitHubRepository -Name 'o/new' -Visibility private
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'create', 'o/new', '--private') -Actual $call.Arguments -Message 'The visibility becomes gh''s --public/--private/--internal flag'
    Assert-Equal -Expected 'https://github.com/o/new' -Actual $url -Message 'The new repository''s URL is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every option, with clone chatter ahead of the URL
$fake = New-FakeGitHubCli -Output @('Cloning into ''new''...', 'https://github.com/o/new')
try {
    # Act
    $url = New-GitHubRepository -Name 'new' -Visibility public -Description 'd' -Homepage 'https://h' -AddReadme -Gitignore 'VisualStudio' -License 'mit' -Template 'o/tpl' -IncludeAllBranches -DisableIssues -DisableWiki -Team 'devs' -Source '.' -Remote 'upstream' -Push -Clone
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'create', 'new', '--public', '--description', 'd', '--homepage', 'https://h', '--add-readme', '--gitignore', 'VisualStudio', '--license', 'mit', '--template', 'o/tpl', '--include-all-branches', '--disable-issues', '--disable-wiki', '--team', 'devs', '--source', '.', '--remote', 'upstream', '--push', '--clone') -Actual $call.Arguments -Message 'Each option becomes its gh flag'
    Assert-Equal -Expected 'https://github.com/o/new' -Actual $url -Message 'The URL is picked out from among other output lines'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
