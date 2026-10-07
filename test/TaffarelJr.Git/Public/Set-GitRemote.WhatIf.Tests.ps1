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

$repo = New-GitTestRepo
$folder = New-GitTestFolder
try {
    git -C $repo remote add upstream 'https://example.invalid/u/r.git' 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - a new remote, with a credential in its URL
    $run = Get-WhatIfOutput {
        Set-GitRemote -Name 'origin' -Url 'https://u:s3cret@h.invalid/o.git' -RepoPath $repo -WhatIf
    }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) -Message '-WhatIf adds no remote'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @(
        'What if: Performing the operation "Add remote with URL https://***@h.invalid/o.git"' +
        " on target ""$repo remote origin""."
    ) -Actual $run.Messages -Message '-WhatIf names the repository and the remote, and hides the credential'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - a remote that exists
    $run = Get-WhatIfOutput {
        Set-GitRemote 'upstream' 'https://u:s3cret@h.invalid/x.git' -RepoPath $repo -WhatIf
    }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) -Message '-WhatIf repoints no remote'
    Assert-Equal -Expected @(
        'What if: Performing the operation "Set URL to https://***@h.invalid/x.git"' +
        " on target ""$repo remote upstream""."
    ) -Actual $run.Messages -Message '-WhatIf says it would repoint a remote that exists'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Set-GitRemote -Name 'origin' -Url '--upload-pack=x' -RepoPath $repo -WhatIf } `
        -MessageLike "*'--upload-pack=x' is blank or starts with '-'*" `
        -Message '-WhatIf still refuses a URL that starts with a dash'
    Assert-Throws -ScriptBlock {
        Set-GitRemote -Name 'origin' -Url 'https://h.invalid/o.git' -RepoPath $folder -WhatIf
    } `
        -MessageLike '*Listing remotes failed*not a git repository*' `
        -Message '-WhatIf still refuses a folder that is no repository'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a new remote with a name git would refuse
    Assert-Throws -ScriptBlock { Set-GitRemote -Name 'a b' -Url 'https://h.invalid/o.git' -RepoPath $repo -WhatIf } `
        -MessageLike "Adding the a b remote failed: 'a b' is not a valid remote name." `
        -Message '-WhatIf refuses a malformed remote name'
    Assert-Throws -ScriptBlock { Set-GitRemote -Name 'a b' -Url 'https://h.invalid/o.git' -RepoPath $repo } `
        -MessageLike "Adding the a b remote failed: 'a b' is not a valid remote name." `
        -Message 'and so does the real call'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $folder
}

exit (Complete-TestRun)
