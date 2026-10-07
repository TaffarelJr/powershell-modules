#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# One check of what a failing call does, for each kind of function body: one
# with no named block, one with only a process block, and one with begin,
# process and end. A plain throw is skipped under -ErrorAction
# SilentlyContinue or Ignore and the function carries on to the change it was
# guarding against, so each public function catches what its blocks throw and
# raises it again as a terminating error.
#
# Whether a call carries on shows only in a script with no try around it, which
# no test file is: the runner wraps every file, and a terminating error inside
# a try ends the statement's caller instead. So those calls are made by a
# script of their own, in a new process, and the files report what happened.

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot 'GitTestHelper.ps1')

$skipReason = Get-GitTestSkipReason
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

$messageAmend = 'Committing failed: -Message is required unless both -Amend and -NoEdit are set.'
$messageClimb = "Deleting a/../.. failed: -Path 'a/../..' climbs above the repository root.*"
$plainScript = @'
param($SourceRoot, $TestFolder, $Repo, $Files, $Folder)

Import-Module (Join-Path $SourceRoot 'TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1')
Import-Module (Join-Path $SourceRoot 'TaffarelJr.Git/TaffarelJr.Git.psd1')
. (Join-Path $TestFolder 'GitTestHelper.ps1')

function Write-Result {
    param($Name, $Output, $Before, $After)
    "RESULT: $Name output=$(@($Output).Count) unchanged=$($Before -ceq $After)"
}

foreach ($preference in 'SilentlyContinue', 'Ignore') {
    $before = Get-GitTestRepoState -Repo $Repo
    $output = @(New-GitCommit -Amend -RepoPath $Repo -ErrorAction $preference)
    Write-Result "no named block, $preference" $output $before (Get-GitTestRepoState -Repo $Repo)

    $before = Get-GitTestRepoState -Repo $Files
    $output = @(Remove-GitFile -Path 'a/../..' -Recurse -Force -RepoPath $Files -ErrorAction $preference)
    Write-Result "process block, $preference" $output $before (Get-GitTestRepoState -Repo $Files)

    $before = Get-GitTestRepoState -Repo $Repo
    $output = @(Add-GitChange -Path 'a/../..' -RepoPath $Repo -ErrorAction $preference)
    Write-Result "process of begin, process, end, $preference" $output $before (Get-GitTestRepoState -Repo $Repo)

    $output = @(Add-GitChange -RepoPath $Folder -ErrorAction $preference)
    Write-Result "end of begin, process, end, $preference" $output 'same' 'same'

    $output = @(New-GitBranch -Name 'main' -RepoPath $Repo -WhatIf -ErrorAction $preference)
    Write-Result "-WhatIf, $preference" $output 'same' 'same'
}
'@

$repo = New-GitTestRepo
$folder = New-GitTestFolder
$files = New-GitTestPathRepo -Path 'b.txt', 'c.txt'
$script = Join-Path ([System.IO.Path]::GetTempPath()) "error-boundary-$([guid]::NewGuid()).ps1"
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a staged change, which an amend would fold into the last commit
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'staged' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    Set-Content -LiteralPath $script -Value $plainScript
    $pwsh = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName

    # Act - every failing call, made by a plain script that has no try around it
    $lines = @(& $pwsh -NoProfile -NonInteractive -File $script `
            -SourceRoot (Join-Path $repoRoot 'src') -TestFolder $PSScriptRoot `
            -Repo $repo -Files $files -Folder $folder 2>&1)

    # Assert
    $results = @($lines | Where-Object { $_ -is [string] -and $_.StartsWith('RESULT: ') })
    Assert-Equal -Expected 10 -Actual $results.Count -Message 'The plain script reported on every call'
    foreach ($preference in 'SilentlyContinue', 'Ignore') {
        foreach ($case in 'no named block', 'process block', 'process of begin, process, end') {
            Assert-Equal -Expected @("RESULT: $case, $preference output=0 unchanged=True") `
                -Actual @($results | Where-Object { $_ -like "RESULT: $case, $preference *" }) `
                -Message "-ErrorAction ${preference}: a failing $case returns nothing, and no change follows"
        }

        Assert-Equal -Expected @("RESULT: end of begin, process, end, $preference output=0 unchanged=True") `
            -Actual @($results | Where-Object { $_ -like "RESULT: end of begin, process, end, $preference *" }) `
            -Message "-ErrorAction ${preference}: a failing end block returns nothing"
        Assert-Equal -Expected @("RESULT: -WhatIf, $preference output=0 unchanged=True") `
            -Actual @($results | Where-Object { $_ -like "RESULT: -WhatIf, $preference *" }) `
            -Message "-ErrorAction ${preference}: a failing check under -WhatIf returns nothing"
    }

    Assert-Equal -Expected 0 -Actual @($lines | Where-Object { "$_" -like 'What if:*' }).Count `
        -Message 'and none of them goes on to say what -WhatIf would do'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the staged change is still there, so an amend still has something to fold in
    # Act
    $caught = $null
    try {
        New-GitCommit -Amend -RepoPath $repo
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected 'RuntimeException,New-GitCommit' -Actual $caught.FullyQualifiedErrorId `
        -Message 'A function with no named block raises an ID that names the kind of failure and the command'
    Assert-Equal -Expected 'InvalidOperation' -Actual "$($caught.CategoryInfo.Category)" `
        -Message 'a category a caller can act on'
    Assert-Equal -Expected $messageAmend -Actual $caught.TargetObject -Message 'the target a throw gave it'
    Assert-Equal -Expected $messageAmend -Actual $caught.Exception.Message -Message 'and the message it was thrown with'
    Assert-Throws -ScriptBlock { New-GitCommit -Amend -RepoPath $repo -ErrorAction Stop } `
        -MessageLike $messageAmend -Message '-ErrorAction Stop still stops the call'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a branch name that is taken, and a call that would only say what it would do
    $before = Get-GitTestRepoState -Repo $repo

    # Act - caught, so what -WhatIf printed before the failure shows up
    $run = Get-WhatIfOutput -CaptureError {
        New-GitBranch -Name 'main' -RepoPath $repo -WhatIf -ErrorAction SilentlyContinue
    }

    # Assert
    Assert-Equal -Expected 0 -Actual $run.Messages.Count `
        -Message 'A failing check under -WhatIf does not go on to say what -WhatIf would do'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message 'and returns nothing'
    Assert-Equal -Expected 'RuntimeException,New-GitBranch' -Actual $run.Error.FullyQualifiedErrorId `
        -Message 'but still raises the failure, for a caller that catches it'
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) -Message 'and changes nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a function with only a process block, and a path that climbs above the root
    $caught = $null
    try {
        Remove-GitFile -Path 'a/../..' -Recurse -Force -RepoPath $files
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected 'RuntimeException,Remove-GitFile' -Actual $caught.FullyQualifiedErrorId `
        -Message 'A failing process block raises an ID that names the failure and the command'
    Assert-Equal -Expected 'InvalidOperation' -Actual "$($caught.CategoryInfo.Category)" -Message 'a category'
    Assert-That -Condition ($caught.TargetObject -like $messageClimb) -Message 'and the target a throw gave it'
    Assert-Throws -ScriptBlock { Remove-GitFile -Path 'a/../..' -RepoPath $files -ErrorAction Stop } `
        -MessageLike $messageClimb -Message '-ErrorAction Stop still stops the call'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a failing record in a pipeline of paths: the one before it is removed, the one after is not
    $caught = $null
    try {
        'b.txt', 'a/../..', 'c.txt' | Remove-GitFile -RepoPath $files
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-That -Condition ($caught.TargetObject -like $messageClimb) -Message 'A failing record raises its error'
    Assert-Equal -Expected @('a.txt', 'c.txt') -Actual @(git -C $files ls-files) `
        -Message 'and stops the pipeline: b.txt was removed, and c.txt, after the failing record, was not'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - names in a pipeline of branches
    git -C $repo branch merged 2>&1 | Out-Null
    git -C $repo branch other 2>&1 | Out-Null

    # Act
    $caught = $null
    try {
        'merged', 'nope', 'other' | Remove-GitBranch -RepoPath $repo
    }
    catch {
        $caught = $_
    }

    # Assert
    $noBranch = "Deleting branch nope failed: there is no branch named 'nope'."
    Assert-Equal -Expected $noBranch -Actual $caught.TargetObject `
        -Message 'A failing branch name raises its error'
    Assert-Equal -Expected @('main', 'other') -Actual @(Get-GitBranch -List -RepoPath $repo) `
        -Message 'and stops the pipeline: merged was deleted, and other, after the failing name, was not'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a function with begin, process and end blocks, and a failure in each of the last two
    Set-Content -LiteralPath (Join-Path $repo 'new.txt') -Value 'new' -NoNewline
    $before = Get-GitTestRepoState -Repo $repo

    # Act - the end block fails when there is no repository to stage in
    $caught = $null
    try {
        Add-GitChange -RepoPath $folder -WhatIf
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected 'RuntimeException,Add-GitChange' -Actual $caught.FullyQualifiedErrorId `
        -Message 'A failing end block raises an ID that names the failure and the command'
    Assert-Equal -Expected 'InvalidOperation' -Actual "$($caught.CategoryInfo.Category)" -Message 'a category'
    Assert-That -Condition ($caught.TargetObject -like 'Staging changes failed: * is not inside a git working tree*') `
        -Message 'and the target a throw gave it'
    Assert-Throws -ScriptBlock { Add-GitChange -RepoPath $folder -ErrorAction Stop } `
        -MessageLike 'Staging changes failed: * is not inside a git working tree*' `
        -Message '-ErrorAction Stop still stops the call'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a failing record in a pipeline whose function collects its paths: nothing is staged at all
    $caught = $null
    try {
        'new.txt', 'a/../..' | Add-GitChange -RepoPath $repo
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-That -Condition ($caught.TargetObject -like "Staging changes failed: -Path 'a/../..' climbs*") `
        -Message 'A failing record raises its error'
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message 'and stops the pipeline before the end block stages the record that came first'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - every function that takes -RepoPath, given one on a drive that does not exist, so that it
    # fails before git is started; a value is made up for each argument a function cannot do without
    $made = @{
        Name = 'x'; Ref = 'main'; Ref1 = 'main'; Ref2 = 'main'; FromRef = 'main'; ToRef = 'main'; Base = 'main'
        Upstream = 'main'; Ancestor = 'main'; Descendant = 'main'; Path = 'x.txt'; Destination = 'y.txt'; Value = 'v'
        Side = 'Ours'; Url = 'https://example.com/x.git'; Message = 'm'
    }
    $common = [System.Management.Automation.PSCmdlet]::CommonParameters +
    [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
    $commands = @(Get-Command -Module TaffarelJr.Git | Where-Object { $_.Parameters.ContainsKey('RepoPath') })

    # Act - from a folder that is no repository, in case a call did reach git
    $outcomes = @()
    Push-Location -LiteralPath $folder
    try {
        foreach ($command in $commands) {
            $setName = $command.DefaultParameterSet
            if (-not $setName) {
                $setName = $command.ParameterSets[0].Name
            }

            $set = $command.ParameterSets | Where-Object Name -EQ $setName
            $given = @{ RepoPath = 'NoSuchDrive:\repo' }
            foreach ($parameter in $set.Parameters) {
                if ($parameter.IsMandatory -and $parameter.Name -notin $common) {
                    $given[$parameter.Name] = $made[$parameter.Name]
                }
            }

            if ($command.Parameters.ContainsKey('Message')) {
                $given.Message = $made.Message
            }

            if ($command.Parameters.ContainsKey('WhatIf')) {
                $given.WhatIf = $true
            }

            $output = @()
            $caught = $null
            try {
                $output = @(& $command.Name @given)
            }
            catch {
                $caught = $_
            }

            $outcomes += [PSCustomObject]@{
                Name     = $command.Name
                Output   = $output.Count
                Id       = if ($caught) { $caught.FullyQualifiedErrorId }
                Category = if ($caught) { "$($caught.CategoryInfo.Category)" }
            }
        }
    }
    finally {
        Pop-Location
    }

    # Assert
    Assert-That -Condition ($outcomes.Count -ge 40) `
        -Message 'Precondition: the functions that take -RepoPath were found'
    foreach ($outcome in $outcomes) {
        Assert-Equal -Expected 0 -Actual $outcome.Output -Message "$($outcome.Name) returns nothing when it fails"
        Assert-That -Condition ($outcome.Id -like "*,$($outcome.Name)") `
            -Message "$($outcome.Name) raises a terminating error whose ID ends with its own name ($($outcome.Id))"
        Assert-Equal -Expected 'InvalidOperation' -Actual $outcome.Category `
            -Message "$($outcome.Name) gives the error a category a caller can act on"
    }
}
finally {
    Remove-Item -LiteralPath $script -Force -ErrorAction SilentlyContinue
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $folder
    Remove-GitTestRepo -Path $files
}

exit (Complete-TestRun)
