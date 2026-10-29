#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force -PassThru
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$skipReason = Get-GitTestSkipReason
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

$repo = New-GitTestPathRepo -Path 'b.txt', 'clean.txt'
$folder = New-GitTestFolder
try {
    git -C $repo checkout -q -b branch-a 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'a-from-a' -NoNewline
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'b-from-a' -NoNewline
    git -C $repo commit --quiet -am 'change on a' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'a-from-main' -NoNewline
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'b-from-main' -NoNewline
    git -C $repo commit --quiet -am 'change on main' 2>&1 | Out-Null
    git -C $repo merge --no-edit branch-a 2>&1 | Out-Null
    $a = Join-Path $repo 'a.txt'
    $b = Join-Path $repo 'b.txt'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act
    $run = Get-WhatIfOutput { Resolve-GitConflict -Path 'a.txt' -Side Theirs -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf neither checks out a side nor stages the path'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Keep the Theirs side and mark it resolved"" on target ""$a""."
    ) -Actual $run.Messages -Message '-WhatIf names the full path and the side, once for both steps'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo
    $conflicts = @(Get-GitConflict -RepoPath $repo)

    # Act - two conflicted paths from the pipeline
    $run = Get-WhatIfOutput { $conflicts | Resolve-GitConflict -Side Ours -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf resolves neither piped path'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Keep the Ours side and mark it resolved"" on target ""$a""."
        "What if: Performing the operation ""Keep the Ours side and mark it resolved"" on target ""$b""."
    ) -Actual $run.Messages -Message '-WhatIf reports each piped path'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Resolve-GitConflict -Path 'src/../../x.txt' -Side Ours -RepoPath $repo -WhatIf } `
        -MessageLike "*-Path 'src/../../x.txt' climbs above the repository root*" `
        -Message '-WhatIf still refuses a path that climbs above the root'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Resolve-GitConflict -Path 'clean.txt' -Side Ours -RepoPath $repo -WhatIf } `
        -MessageLike "Keeping the Ours side of clean.txt failed: -Path 'clean.txt' has no conflict to resolve." `
        -Message '-WhatIf still refuses a path with no conflict'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a folder that is no repository
    Assert-Throws -ScriptBlock { Resolve-GitConflict -Path 'a.txt' -Side Ours -RepoPath $folder -WhatIf } `
        -MessageLike "Keeping the Ours side of a.txt failed: '$folder' is not inside a git working tree (*" `
        -Message '-WhatIf refuses a folder that is no repository'
    Assert-Throws -ScriptBlock { Resolve-GitConflict -Path 'a.txt' -Side Ours -RepoPath $folder } `
        -MessageLike "Keeping the Ours side of a.txt failed: '$folder' is not inside a git working tree (*" `
        -Message 'and so does the real call'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a stand-in for Add-GitChange that records what it was told
    $original = & $module { ${function:Add-GitChange} }
    & $module {
        $script:handOff = [System.Collections.Generic.List[string]]::new()
        function script:Add-GitChange {
            [CmdletBinding(SupportsShouldProcess)]
            param(
                [string[]]$Path,

                [string]$RepoPath
            )

            $told = "WhatIf=$($PSBoundParameters['WhatIf']) Confirm=$($PSBoundParameters['Confirm'])"
            if ($PSCmdlet.ShouldProcess($Path, 'Record the hand-off')) {
                $script:handOff.Add($told)
            }
        }
    }

    # Act - once approved, the staging step is never asked about again
    try {
        Resolve-GitConflict -Path 'a.txt' -Side Ours -RepoPath $repo
        $handOff = & $module { $script:handOff }
    }
    finally {
        & $module { param($Body) ${function:script:Add-GitChange} = $Body } $original
    }

    # Assert
    Assert-Equal -Expected @('WhatIf=False Confirm=False') -Actual @($handOff) `
        -Message 'Add-GitChange is told -WhatIf:$false and -Confirm:$false, so it neither asks again nor skips'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $folder
}

exit (Complete-TestRun)
