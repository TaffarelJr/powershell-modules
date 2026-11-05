#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

if (-not (Test-LiveGitHub)) {
    exit (Skip-TestRun -Reason 'gh has no working login here')
}

if ($null -eq (Get-Command -Name 'git' -ErrorAction SilentlyContinue)) {
    exit (Skip-TestRun -Reason 'git is not available here')
}

# A default repository lives in a clone's own git config, so every call here is
# made inside a throwaway repository and none of it touches a real one.
$clone = Join-Path ([IO.Path]::GetTempPath()) "default-repo-$([Guid]::NewGuid())"
$bare = Join-Path ([IO.Path]::GetTempPath()) "no-remotes-$([Guid]::NewGuid())"
foreach ($folder in $clone, $bare) {
    New-Item -ItemType Directory -Path $folder | Out-Null
    git -C $folder init -q
}

git -C $clone remote add origin 'https://github.com/cli/cli.git'

Push-Location -LiteralPath $clone
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act - a clone with a GitHub remote and no default chosen
    $before = Get-GitHubDefaultRepository

    # Assert
    Assert-That -Condition ($null -eq $before) `
        -Message 'A clone with no default chosen answers $null, not gh''s message'

    #───────────────────────────────────────────────────────────────────────────
    # Act - choosing one, and clearing it again
    Set-GitHubDefaultRepository -Repository 'cli/cli'
    $chosen = Get-GitHubDefaultRepository
    Set-GitHubDefaultRepository -Unset
    $cleared = Get-GitHubDefaultRepository

    # Assert
    Assert-Equal -Expected 'cli/cli' -Actual $chosen -Message 'The chosen default is read back as OWNER/REPO'
    Assert-That -Condition ($null -eq $cleared) -Message 'and answers $null again once cleared'
}
finally {
    Pop-Location
}

Push-Location -LiteralPath $bare
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a repository with no remote at all, which gh cannot answer for
    Assert-Throws -ScriptBlock {
        Get-GitHubDefaultRepository
    } -MessageLike '*Reading the default repository failed*no git remotes found*' `
        -Message 'A failure to read it throws with gh''s message, and is not mistaken for "none set"'
}
finally {
    Pop-Location
    Remove-Item -LiteralPath $clone, $bare -Recurse -Force
}

exit (Complete-TestRun)
