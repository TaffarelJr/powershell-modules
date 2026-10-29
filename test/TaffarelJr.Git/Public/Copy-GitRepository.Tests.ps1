#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$skipReason = Get-GitTestSkipReason
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

$source = New-GitTestRepo
$destination = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act
    Copy-GitRepository -Url $source -Destination $destination

    # Assert
    Assert-Equal -Expected $true -Actual (Test-GitRepository -RepoPath $destination) `
        -Message 'The destination is a real git repo'
    Assert-Equal -Expected (Resolve-GitRef -Ref 'HEAD' -RepoPath $source) `
        -Actual (Resolve-GitRef -Ref 'HEAD' -RepoPath $destination) `
        -Message 'The clone has the same history as the source'
    Assert-Equal -Expected $source -Actual (Get-GitRemote -Name 'origin' -RepoPath $destination) `
        -Message "The clone's origin points back at the source"

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a source with a second branch, and a clone of just that one
    git -C $source branch other 2>&1 | Out-Null
    $branchClone = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"

    # Act
    Copy-GitRepository -Url $source -Destination $branchClone -Branch 'other'

    # Assert
    Assert-Equal -Expected 'other' -Actual (Get-GitBranch -RepoPath $branchClone) `
        -Message '-Branch checks that branch out instead of the remote''s default'
    Remove-GitTestRepo -Path $branchClone

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert - a URL that is really a git option, which would
    # run a command of the caller's choosing
    Assert-Throws -ScriptBlock {
        Copy-GitRepository -Url '--upload-pack=echo-not-run' -Destination $destination
    } -MessageLike "*'--upload-pack=echo-not-run' is blank or starts with '-'*" `
        -Message 'A URL starting with a dash is refused before git sees it'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a destination folder whose name starts with a dash, made
    # relative to a folder of its own
    $workFolder = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $workFolder | Out-Null

    # Act
    Push-Location -LiteralPath $workFolder
    try {
        Copy-GitRepository -Url $source -Destination '-dash'
    }
    finally {
        Pop-Location
    }

    # Assert
    Assert-Equal -Expected $true -Actual (Test-GitRepository -RepoPath (Join-Path $workFolder '-dash')) `
        -Message 'A destination starting with a dash is a folder, not an option'
    Remove-GitTestRepo -Path $workFolder

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a URL carrying a (fake) token, to a port nothing listens on
    $token = 'fake-token-0123456789'
    $tokenClone = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
    $thrown = $null

    # Act
    try {
        Copy-GitRepository -Url "http://x-access-token:$token@127.0.0.1:1/x.git" -Destination $tokenClone
    }
    catch {
        $thrown = $_.Exception.Message
    }

    # Assert
    $hidden = [WildcardPattern]::Escape('Cloning http://***@127.0.0.1:1/x.git failed')
    Assert-That -Condition ($thrown -like "*$hidden*") -Message 'A failed clone says which URL, without its credential'
    Assert-That -Condition ($thrown -notlike "*$token*") -Message 'so the token appears nowhere in the message'
    Remove-GitTestRepo -Path $tokenClone

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an e-mail address as the user name, and a pasted token holding
    # a '/' and a space
    $pasted = 'fake/token 0123456789'
    $pastedClone = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
    $pastedThrown = $null

    # Act
    try {
        Copy-GitRepository -Url "http://me@example.com:$pasted@127.0.0.1:1/x.git" -Destination $pastedClone
    }
    catch {
        $pastedThrown = $_.Exception.Message
    }

    # Assert
    Assert-That -Condition ($pastedThrown -like "*$hidden*") `
        -Message 'A failed clone hides an e-mail user name with its password'
    Assert-That -Condition ($pastedThrown -notlike '*0123456789*') `
        -Message 'so no part of the token appears in the message'
    Remove-GitTestRepo -Path $pastedClone
}
finally {
    Remove-GitTestRepo -Path $source
    Remove-GitTestRepo -Path $destination
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a hook's repository, with a file staged in its index, whose index
# and working tree the inherited variables name
$hookRepo = New-GitTestRepo
Set-Content -LiteralPath (Join-Path $hookRepo 'staged.txt') -Value 's' -NoNewline
git -C $hookRepo add -A 2>&1 | Out-Null
$source = New-GitTestPathRepo -Path 'only-in-source.txt'
$destination = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
$env:GIT_INDEX_FILE = Join-Path $hookRepo '.git/index'
$env:GIT_WORK_TREE = $hookRepo

# Act
try {
    Copy-GitRepository -Url $source -Destination $destination
}
finally {
    Remove-Item -LiteralPath Env:GIT_INDEX_FILE, Env:GIT_WORK_TREE
}

$hookIndex = (git -C $hookRepo ls-files) -join ', '
$cloneIndex = (git -C $destination ls-files) -join ', '

# Assert
try {
    Assert-Equal -Expected 'a.txt, staged.txt' -Actual $hookIndex `
        -Message 'A clone run from a hook leaves the hook''s index alone'
    Assert-Equal -Expected 'a.txt, only-in-source.txt' -Actual $cloneIndex -Message 'and writes its own'
}
finally {
    Remove-GitTestRepo -Path $hookRepo
    Remove-GitTestRepo -Path $source
    Remove-GitTestRepo -Path $destination
}

exit (Complete-TestRun)
