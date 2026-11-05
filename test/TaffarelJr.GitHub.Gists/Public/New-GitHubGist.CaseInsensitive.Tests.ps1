#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'GitHubGistsTestHelper.ps1')

$folder = New-GistTestFolder -File @{ 'Notes.md' = 'N' }
if (-not (Test-Path -LiteralPath (Join-Path $folder 'notes.md'))) {
    Remove-Item -LiteralPath $folder -Recurse -Force
    exit (Skip-TestRun -Reason 'the temporary folder is on a case-sensitive file system')
}

$created = '{"id":"abc123","html_url":"https://gist.github.com/me/abc123"}'
$elsewhere = [System.IO.Path]::GetTempPath()
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file typed in another case than its own
    $fake = New-FakeGitHubCli -Output @($created)
    try {
        # Act
        Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
            New-GitHubGist -Path 'notes.md' | Out-Null
        }
        $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

        # Assert
        Assert-Equal -Expected '{"description":"","files":{"Notes.md":{"content":"N"}},"public":false}' `
            -Actual $call.StdIn `
            -Message 'The gist file takes the name the file system has, not the case it was typed in'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - one file typed twice, in two cases
    $fake = New-FakeGitHubCli -Output @($created)
    try {
        # Act / Assert
        Assert-Throws -ScriptBlock {
            Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
                New-GitHubGist -Path @('Notes.md', 'notes.md')
            }
        } -MessageLike "-Path names the file '$(Join-Path $folder 'Notes.md')' more than once: give each file once." `
            -Message 'is one file named twice, refused before it is sent twice'
        Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - Set-GitHubGist adding a file typed in another case than its own
    $fake = New-FakeGitHubCli -Sequence @(
        @{ Output = '{"id":"abc123","files":{"other.txt":{}}}' }
        @{ Output = @() }
    )
    try {
        # Act
        Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
            Set-GitHubGist -Id 'abc123' -AddFile 'notes.md'
        }
        $calls = @(Get-FakeGitHubCall -Fixture $fake)

        # Assert
        Assert-Equal -Expected @('gist', 'edit', '--add', (Join-Path $folder 'Notes.md'), 'abc123') `
            -Actual $calls[1].Arguments `
            -Message 'gh is given the file under the name the file system has, which the gist file takes'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - Set-GitHubGist adding, in another case, a file the gist has
    $fake = New-FakeGitHubCli -Output @('{"id":"abc123","files":{"Notes.md":{}}}')
    try {
        # Act / Assert
        Assert-Throws -ScriptBlock {
            Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
                Set-GitHubGist -Id 'abc123' -AddFile 'notes.md'
            }
        } -MessageLike "Gist abc123 already has a file named 'Notes.md', which -AddFile would silently replace;*" `
            -Message 'is refused, the names compared as the file system has them'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}
finally {
    Remove-Item -LiteralPath $folder -Recurse -Force
}

exit (Complete-TestRun)
