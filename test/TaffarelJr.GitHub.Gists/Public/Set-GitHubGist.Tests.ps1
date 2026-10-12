#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - description, add, and remove
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubGist -Id 'abc123' -Description 'new desc' -AddFile 'new.txt' -RemoveFile 'old.txt'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('gist', 'edit', 'abc123', '--desc', 'new desc', '--add', 'new.txt', '--remove', 'old.txt') -Actual $call.Arguments -Message 'The id is positional and each option becomes its gh flag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - replacing a file's content from a local file
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubGist -Id 'abc123' -FileName 'hello.py' -ReplaceWith 'hello.py'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('gist', 'edit', 'abc123', '--filename', 'hello.py', 'hello.py') -Actual $call.Arguments -Message '-FileName selects the file and -ReplaceWith supplies its new content positionally'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gist ids from the pipeline
$fake = New-FakeGitHubCli
try {
    # Act
    @('a', 'b') | Set-GitHubGist -Description 'x'
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped gist is edited in its own call'
    Assert-Equal -Expected @('gist', 'edit', 'b', '--desc', 'x') -Actual $calls[1].Arguments -Message 'The second piped gist is edited too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
