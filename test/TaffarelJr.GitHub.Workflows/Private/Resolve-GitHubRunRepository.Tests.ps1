#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') `
    -Force `
    -PassThru

$resolve = {
    param($InputObject, $RunId, $Repository, $NoRun)
    Resolve-GitHubRunRepository -InputObject $InputObject -RunId $RunId -Repository $Repository `
        -Advice 'Do this instead.' `
        -NoRun:$NoRun
}
$advice = ' Give a run Get-GitHubWorkflowRun returned, or its DatabaseId.'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - runs, and values with nothing to say
$passing = @(
    @{
        InputObject = $null
        RunId       = 9
        Repository  = 'a/b'
        NoRun       = $false
        Expected    = 'a/b'
        Message     = 'No object passes'
    }
    @{
        InputObject = 9
        RunId       = 9
        Repository  = $null
        NoRun       = $false
        Expected    = $null
        Message     = 'as does a plain id'
    }
    @{
        InputObject = [PSCustomObject]@{ DatabaseId = 9; Url = 'https://github.com/o/r/actions/runs/9' }
        RunId       = 9
        Repository  = $null
        NoRun       = $false
        Expected    = 'https://github.com/o/r'
        Message     = 'A run with its own Url passes, acted on in the repository of that Url'
    }
    @{
        InputObject = [PSCustomObject]@{ DatabaseId = 9; Url = 'https://github.com/o/r/actions/runs/9/attempts/2' }
        RunId       = 9
        Repository  = $null
        NoRun       = $false
        Expected    = 'https://github.com/o/r'
        Message     = 'as does one whose Url goes on past the run id'
    }
    @{
        InputObject = [PSCustomObject]@{ DatabaseId = 9; Repository = 'o/r' }
        RunId       = 9
        Repository  = 'o/r'
        NoRun       = $false
        Expected    = 'o/r'
        Message     = 'A run with no Url passes, in its Repository'
    }
    @{
        InputObject = [PSCustomObject]@{ Url = 'https://github.com/o/r/actions/runs/5'; Repository = 'o/r' }
        RunId       = 0
        Repository  = 'o/r'
        NoRun       = $true
        Expected    = 'o/r'
        Message     = 'A call that names no run reads a piped run for its repository only'
    }
    @{
        InputObject = [PSCustomObject]@{
            DatabaseId = 42
            Steps      = @()
            Url        = 'https://github.com/o/r/actions/runs/9/job/42'
        }
        RunId       = 42
        Repository  = $null
        NoRun       = $true
        Expected    = 'https://github.com/o/r'
        Message     = 'and a piped job too, whatever its DatabaseId bound as'
    }
)

# Act / Assert
foreach ($case in $passing) {
    $reference = & $module $resolve $case.InputObject $case.RunId $case.Repository $case.NoRun
    Assert-Equal -Expected $case.Expected -Actual $reference -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - objects that are no run
$refused = @(
    @{
        InputObject = [PSCustomObject]@{ DatabaseId = 42; Url = 'https://github.com/o/r/actions/runs/9/job/42' }
        RunId       = 42
        NoRun       = $false
        Pattern     = 'A job is not a run: its DatabaseId is the job''s own, not its run''s. Do this instead.'
        Message     = 'A /job/ Url is a job, refused with the advice given'
    }
    @{
        InputObject = [PSCustomObject]@{ DatabaseId = 42; Steps = @() }
        RunId       = 42
        NoRun       = $false
        Pattern     = 'A job is not a run: its DatabaseId is the job''s own, not its run''s. Do this instead.'
        Message     = 'as is an object with Steps'
    }
    @{
        InputObject = [PSCustomObject]@{ DatabaseId = 9; Url = 'https://github.com/o/r/releases/tag/v1' }
        RunId       = 9
        NoRun       = $false
        Pattern     = "The object piped in is not a workflow run: its Url 'https://github.com/o/r/releases/tag/v1'" +
        " is not workflow run 9's.$advice"
        Message     = 'An object whose Url is not a run''s is refused'
    }
    @{
        InputObject = [PSCustomObject]@{ DatabaseId = 9; Url = 'https://github.com/o/r/actions/runs/91' }
        RunId       = 9
        NoRun       = $false
        Pattern     = "The object piped in is not a workflow run: its Url 'https://github.com/o/r/actions/runs/91'" +
        " is not workflow run 9's.$advice"
        Message     = 'as is one whose Url is another run''s'
    }
    @{
        InputObject = [PSCustomObject]@{ Url = 'https://github.com/o/r/issues/1' }
        RunId       = 0
        NoRun       = $true
        Pattern     = "The object piped in is not a workflow run: its Url 'https://github.com/o/r/issues/1'" +
        " is not a workflow run's.$advice"
        Message     = 'and, where the call names no run, one whose Url is no run''s at all'
    }
    @{
        InputObject = [PSCustomObject]@{ Id = 5; Key = 'npm-abc' }
        RunId       = 0
        NoRun       = $false
        Pattern     = "The object piped in is not a workflow run: it has no DatabaseId.$advice"
        Message     = 'An object that bound no run id is refused'
    }
)

# Act / Assert
foreach ($case in $refused) {
    Assert-Throws -ScriptBlock {
        & $module $resolve $case.InputObject $case.RunId $null $case.NoRun
    } -MessageLike $case.Pattern -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a run from one repository, with a -Repository naming another
$run = [PSCustomObject]@{ DatabaseId = 9; Url = 'https://github.com/o/r/actions/runs/9' }

# Act / Assert
Assert-Throws -ScriptBlock {
    & $module { param($r) Resolve-GitHubRunRepository -InputObject $r -RunId 9 -Repository 'x/y' -Advice 'A.' } $run
} -MessageLike 'Workflow run 9 is in o/r, but -Repository names x/y: give one or the other.' `
    -Message 'A -Repository naming another repository than the run''s throws, naming the run'
Assert-Throws -ScriptBlock {
    & $module {
        param($r)
        Resolve-GitHubRunRepository -InputObject $r -RunId 0 -Repository 'x/y' -Advice 'A.' -Item 'Job 5' -NoRun
    } $run
} -MessageLike 'Job 5 is in o/r, but -Repository names x/y: give one or the other.' `
    -Message 'or the -Item given'

exit (Complete-TestRun)
