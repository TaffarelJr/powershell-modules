#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'PreferenceTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - each changing function, called from a function that was given -WhatIf
$changes = @(
    @{ Call = { Copy-GitHubGist -Id 'abc123' -Destination 'copy' }; Name = 'Copy-GitHubGist' }
    @{ Call = { New-GitHubGist -Content 'A' -FileName 'a.txt' }; Name = 'New-GitHubGist' }
    @{ Call = { Remove-GitHubGist -Id 'abc123' }; Name = 'Remove-GitHubGist' }
    @{ Call = { Rename-GitHubGistFile -Id 'abc123' -OldName 'a.txt' -NewName 'b.txt' }; Name = 'Rename-GitHubGistFile' }
    @{ Call = { Set-GitHubGist -Id 'abc123' -Description 'New' }; Name = 'Set-GitHubGist' }
)
foreach ($change in $changes) {
    $fake = New-FakeGitHubCli
    try {
        # Act
        $call = $change.Call
        $result = Get-WhatIfOutput -ScriptBlock { Invoke-WhatIfCaller -Call $call -WhatIf }

        # Assert
        Assert-Equal -Expected 1 -Actual $result.Messages.Count `
            -Message "$($change.Name) called from a function given -WhatIf says what it would do"
        Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and does not call gh'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

exit (Complete-TestRun)
