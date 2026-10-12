#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') `
    -Force `
    -PassThru
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

$clock = Use-FakePollClock -Module $module

# Every message is matched whole, its stars escaped, so a SENTINEL left anywhere
# in it fails the case.
$url = 'https://user:SENTINEL@ghe.example.com/o/r'
$shown = 'https://***@ghe.example.com/o/r'
$other = 'https://v:SENTINEL@ghe.example.com/o/other'
$otherShown = 'https://***@ghe.example.com/o/other'
$bare = 'user:SENTINEL@h.example'
$bareShown = '***@h.example'
$runFields = 'attempt,conclusion,createdAt,databaseId,displayTitle,event,headBranch,headSha,name,number,' +
'startedAt,status,updatedAt,url,workflowDatabaseId,workflowName'
$assertMessage = {
    param([scriptblock]$Block, [string]$Expected, [string]$Name)
    Assert-Throws -ScriptBlock $Block -MessageLike ([WildcardPattern]::Escape($Expected)) -Message $Name
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every message that shows a value it was given, with no gh run
$fake = New-FakeGitHubCli
try {
    $workflowHere = [PSCustomObject]@{ Path = $url; Repository = $url }
    $cacheHere = [PSCustomObject]@{ Id = $url; Key = 'npm-abc'; Repository = $url }
    $elsewhere = [PSCustomObject]@{ DatabaseId = 5; Repository = $other }
    $mismatch = "Workflow $shown is in ghe.example.com/o/r, but -Repository names ${otherShown}:" +
    ' give one or the other.'
    $notRepository = "'$shown x' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL."
    $messages = @(
        @{
            Block    = { Start-GitHubWorkflow -Workflow 'ci.yml' -Inputs @{ $bare = 1 } -Repository 'o/r' }
            Expected = "'$bareShown' is not a workflow input name:" +
            ' a name starts with a letter or _ and holds only letters, digits, _ and -.'
            Name     = 'Start-GitHubWorkflow, for an input name that is not one'
        }
        @{
            Block    = { Save-GitHubWorkflowRunArtifact -RunId 5 -Destination "$bare " }
            Expected = "-Destination '$bareShown ' ends in white space, which Windows cannot handle in a folder name:" +
            ' give it without.'
            Name     = 'Save-GitHubWorkflowRunArtifact, for a -Destination ending in white space'
        }
        @{
            Block    = { Save-GitHubWorkflowRunArtifact -RunId 5 -Destination 'Env:/user:SENTINEL@h.example/x' }
            Expected = "'$bareShown/x' is not a file system path (it is on the Environment provider)," +
            ' so gh cannot use it.'
            Name     = 'and for a -Destination on another provider'
        }
        @{
            Block    = { Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @($bare) }
            Expected = "'$bareShown' in -Before is not a run id:" +
            ' give the runs Get-GitHubWorkflowRun -List returned, or their DatabaseId.'
            Name     = 'Wait-GitHubWorkflowRunStart, for text in -Before that is not a run id'
        }
        @{
            Block    = {
                Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @([PSCustomObject]@{ DatabaseId = $bare })
            }
            Expected = "'$bareShown' in -Before is not a run id:" +
            ' give the runs Get-GitHubWorkflowRun -List returned, or their DatabaseId.'
            Name     = 'and for a DatabaseId that is not one'
        }
        @{
            Block    = {
                Wait-GitHubWorkflowRunStart -Workflow ([PSCustomObject]@{ Path = $bare; Repository = $url }) `
                    -Before @($elsewhere)
            }
            Expected = 'Run 5 in -Before is in ghe.example.com/o/other,' +
            " but workflow $bareShown is in ghe.example.com/o/r: list -Before from the workflow's repository."
            Name     = 'and for -Before runs from another repository than the workflow''s'
        }
        @{
            Block    = { Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @($elsewhere) -Repository $url }
            Expected = "Run 5 in -Before is in ghe.example.com/o/other, but -Repository names ${shown}:" +
            ' give one or the other.'
            Name     = 'and for -Before runs from another repository than -Repository names'
        }
        @{
            Block    = {
                [PSCustomObject]@{ DatabaseId = 5; Url = "$url/issues/1" } | Stop-GitHubWorkflowRun
            }
            Expected = "The object piped in is not a workflow run: its Url '$shown/issues/1' is not workflow run 5's." +
            ' Give a run Get-GitHubWorkflowRun returned, or its DatabaseId.'
            Name     = 'Resolve-GitHubRunRepository, for a piped object whose Url is not a run''s'
        }
        @{
            Block    = { Disable-GitHubWorkflow -Workflow $workflowHere -Repository $other }
            Expected = $mismatch
            Name     = 'Disable-GitHubWorkflow, for a workflow from another repository than -Repository'
        }
        @{
            Block    = { Enable-GitHubWorkflow -Workflow $workflowHere -Repository $other }
            Expected = $mismatch
            Name     = 'Enable-GitHubWorkflow, for the same'
        }
        @{
            Block    = { Start-GitHubWorkflow -Workflow $workflowHere -Repository $other }
            Expected = $mismatch
            Name     = 'Start-GitHubWorkflow, for the same'
        }
        @{
            Block    = { Get-GitHubWorkflowRun -List -Workflow $workflowHere -Repository $other }
            Expected = $mismatch
            Name     = 'Get-GitHubWorkflowRun, for the same'
        }
        @{
            Block    = { Wait-GitHubWorkflowRunStart -Workflow $workflowHere -Before @() -Repository $other }
            Expected = $mismatch
            Name     = 'Wait-GitHubWorkflowRunStart, for the same'
        }
        @{
            Block    = { Remove-GitHubCache -Id $cacheHere -Repository $other }
            Expected = "Cache $shown is in ghe.example.com/o/r, but -Repository names ${otherShown}:" +
            ' give one or the other.'
            Name     = 'Remove-GitHubCache, for a cache from another repository than -Repository'
        }
        @{
            Block    = { Disable-GitHubWorkflow -Workflow ([PSCustomObject]@{ Id = 1; Repository = "$url x" }) }
            Expected = $notRepository
            Name     = 'Resolve-GitHubOriginRepository, for a piped object whose Repository is not one'
        }
        @{
            Block    = { Disable-GitHubWorkflow -Workflow 'ci.yml' -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Disable-GitHubWorkflow, for a -Repository that is not one'
        }
        @{
            Block    = { Enable-GitHubWorkflow -Workflow 'ci.yml' -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Enable-GitHubWorkflow, for the same'
        }
        @{
            Block    = { Get-GitHubCache -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Get-GitHubCache, for the same'
        }
        @{
            Block    = { Get-GitHubWorkflow -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Get-GitHubWorkflow, for the same'
        }
        @{
            Block    = { Get-GitHubWorkflowRun -RunId 5 -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Get-GitHubWorkflowRun, for the same'
        }
        @{
            Block    = { Get-GitHubWorkflowRunLog -RunId 5 -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Get-GitHubWorkflowRunLog, for the same'
        }
        @{
            Block    = { Remove-GitHubCache -Id 7 -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Remove-GitHubCache, for the same'
        }
        @{
            Block    = { Remove-GitHubWorkflowRun -RunId 5 -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Remove-GitHubWorkflowRun, for the same'
        }
        @{
            Block    = { Restart-GitHubWorkflowRun -RunId 5 -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Restart-GitHubWorkflowRun, for the same'
        }
        @{
            Block    = { Save-GitHubWorkflowRunArtifact -RunId 5 -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Save-GitHubWorkflowRunArtifact, for the same'
        }
        @{
            Block    = { Start-GitHubWorkflow -Workflow 'ci.yml' -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Start-GitHubWorkflow, for the same'
        }
        @{
            Block    = { Stop-GitHubWorkflowRun -RunId 5 -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Stop-GitHubWorkflowRun, for the same'
        }
        @{
            Block    = { Wait-GitHubWorkflowRun -RunId 5 -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Wait-GitHubWorkflowRun, for the same'
        }
        @{
            Block    = { Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @() -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Wait-GitHubWorkflowRunStart, for the same'
        }
    )

    # Act / Assert
    foreach ($case in $messages) {
        & $assertMessage $case.Block $case.Expected "$($case.Name) shows no credential"
    }

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is called for none'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf, whose targets and actions show names the caller gave
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Disable-GitHubWorkflow -Workflow $url -Repository 'o/r' -WhatIf
        Enable-GitHubWorkflow -Workflow $url -Repository 'o/r' -WhatIf
        Start-GitHubWorkflow -Workflow $url -Ref $bare -Repository 'o/r' -WhatIf
        Remove-GitHubCache -Id $url -Repository 'o/r' -WhatIf
        Remove-GitHubCache -All -Ref $bare -Repository 'o/r' -WhatIf
        Remove-GitHubWorkflowRun -RunId 5 -Repository $url -WhatIf
    }

    # Assert
    $expected = @(
        "What if: Performing the operation `"Disable workflow`" on target `"o/r workflow $shown`"."
        "What if: Performing the operation `"Enable workflow`" on target `"o/r workflow $shown`"."
        "What if: Performing the operation `"Dispatch workflow on $bareShown`" on target `"o/r workflow $shown`"."
        'What if: Performing the operation "Delete every cache with this key, on every ref"' +
        " on target `"o/r cache key $shown`"."
        "What if: Performing the operation `"Delete every cache for $bareShown`" on target `"o/r`"."
        "What if: Performing the operation `"Delete workflow run`" on target `"ghe.example.com/o/r workflow run 5`"."
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages `
        -Message '-WhatIf shows no credential in a workflow name, a cache key, a ref, or the repository'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf for a download into a folder whose name holds a credential,
# in the folder's own separator
$fake = New-FakeGitHubCli
try {
    $separator = [IO.Path]::DirectorySeparatorChar

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Save-GitHubWorkflowRunArtifact -RunId 5 -Destination 'Temp:/user:SENTINEL@h.example/out' `
            -Repository $url -WhatIf
    }

    # Assert
    $line = @($whatIf.Messages)[0]
    $pattern = 'What if: Performing the operation "Download the artifacts of ghe.example.com/o/r workflow run 5"' +
    " on target `"*@h.example${separator}out`"."
    Assert-That -Condition ($whatIf.Messages.Count -eq 1 -and $line -like $pattern) `
        -Message '-WhatIf names the folder, keeping what follows the credential'
    Assert-That -Condition ($line -notmatch 'SENTINEL') -Message 'without the credential'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that fails, echoing the URL, given the URL in every place a
# call carries one
$fake = New-FakeGitHubCli -ErrorOutput @("gh: Forbidden $url") -ExitCode 1
try {
    $tail = "`ngh: Forbidden $shown"
    $failures = @(
        @{
            Block    = { Disable-GitHubWorkflow -Workflow $url -Repository $url }
            Expected = "Disabling workflow $shown failed: gh workflow disable --repo $shown -- $shown (exit 1)$tail"
            Name     = 'Disable-GitHubWorkflow'
        }
        @{
            Block    = { Enable-GitHubWorkflow -Workflow $url -Repository $url }
            Expected = "Enabling workflow $shown failed: gh workflow enable --repo $shown -- $shown (exit 1)$tail"
            Name     = 'Enable-GitHubWorkflow'
        }
        @{
            Block    = { Get-GitHubCache -Key $url -Ref $url -Repository $url }
            Expected = 'Listing caches failed: gh cache list --json' +
            ' createdAt,id,key,lastAccessedAt,ref,sizeInBytes,version' +
            " --key=$shown --ref=$shown --repo $shown (exit 1)$tail"
            Name     = 'Get-GitHubCache'
        }
        @{
            Block    = { Get-GitHubWorkflow -Repository $url }
            Expected = 'Listing workflows failed: gh workflow list --json id,name,path,state' +
            " --repo $shown (exit 1)$tail"
            Name     = 'Get-GitHubWorkflow'
        }
        @{
            Block    = { Get-GitHubWorkflowRun -RunId 5 -Repository $url }
            Expected = "Reading workflow run 5 failed: gh run view 5 --json $runFields,jobs --repo $shown (exit 1)$tail"
            Name     = 'Get-GitHubWorkflowRun, for one run'
        }
        @{
            Block    = { Get-GitHubWorkflowRun -List -Workflow $url -Branch $url -Repository $url }
            Expected = "Listing workflow runs failed: gh run list --json $runFields --workflow $shown --branch=$shown" +
            " --repo $shown (exit 1)$tail"
            Name     = 'and for a list'
        }
        @{
            Block    = { Get-GitHubWorkflowRunLog -RunId 5 -Repository $url }
            Expected = "Reading the workflow run log failed: gh run view 5 --log --repo $shown (exit 1)$tail"
            Name     = 'Get-GitHubWorkflowRunLog'
        }
        @{
            Block    = { Remove-GitHubCache -Id $url -Repository $url }
            Expected = "Deleting cache $shown failed: gh cache delete --repo $shown -- $shown (exit 1)$tail"
            Name     = 'Remove-GitHubCache, for a key'
        }
        @{
            Block    = { Remove-GitHubCache -All -Ref $url -Repository $url }
            Expected = "Deleting every cache failed: gh cache delete --all --ref=$shown --repo $shown (exit 1)$tail"
            Name     = 'and for every cache'
        }
        @{
            Block    = { Remove-GitHubWorkflowRun -RunId 5 -Repository $url }
            Expected = "Deleting workflow run 5 failed: gh run delete 5 --repo $shown (exit 1)$tail"
            Name     = 'Remove-GitHubWorkflowRun'
        }
        @{
            Block    = { Restart-GitHubWorkflowRun -RunId 5 -Repository $url }
            Expected = "Rerunning workflow run 5 failed: gh run rerun 5 --repo $shown (exit 1)$tail"
            Name     = 'Restart-GitHubWorkflowRun'
        }
        @{
            Block    = { Save-GitHubWorkflowRunArtifact -RunId 5 -Name $url -Pattern $url -Repository $url }
            Expected = 'Downloading workflow run artifacts failed: gh run download 5' +
            " --name=$shown --pattern=$shown --repo $shown (exit 1)$tail"
            Name     = 'Save-GitHubWorkflowRunArtifact'
        }
        @{
            Block    = { Start-GitHubWorkflow -Workflow $url -Ref $url -Inputs @{ key = $url } -Repository $url }
            Expected = "Dispatching workflow $shown failed: gh workflow run --ref=$shown --json" +
            " --repo $shown -- $shown (exit 1)$tail"
            Name     = 'Start-GitHubWorkflow'
        }
        @{
            Block    = { Stop-GitHubWorkflowRun -RunId 5 -Repository $url }
            Expected = "Canceling workflow run 5 failed: gh run cancel 5 --repo $shown (exit 1)$tail"
            Name     = 'Stop-GitHubWorkflowRun'
        }
        @{
            Block    = { Wait-GitHubWorkflowRun -RunId 5 -Repository $url }
            Expected = "Could not read workflow run 5 (exit 1):$tail"
            Name     = 'Wait-GitHubWorkflowRun'
        }
        @{
            Block    = { Wait-GitHubWorkflowRunStart -Workflow $url -Before @() -Repository $url }
            Expected = "Could not list the workflow_dispatch runs of '$shown' (exit 1):$tail"
            Name     = 'Wait-GitHubWorkflowRunStart'
        }
    )

    # Act / Assert
    foreach ($case in $failures) {
        & $assertMessage $case.Block $case.Expected "$($case.Name) shows no credential in a failed call"
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a run that stays in a status holding the URL, on a clock that moves
# only when the wait sleeps
$clock.Slept.Clear()
$fake = New-FakeGitHubCli -Output @("{`"status`":`"waiting $url`"}")
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRun -RunId 5 -TimeoutSeconds 1 -PollSeconds 30
    } -ExceptionType ([TimeoutException]) `
        -MessageLike ([WildcardPattern]::Escape(
            "Workflow run 5 was still waiting $shown after 1 s. Give a longer -TimeoutSeconds to wait more.")) `
        -Message 'Wait-GitHubWorkflowRun shows no credential in the timeout'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a workflow named by the URL, whose runs never show a new one
$clock.Slept.Clear()
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRunStart -Workflow $url -Before @() -TimeoutSeconds 1 -PollSeconds 30
    } -ExceptionType ([TimeoutException]) `
        -MessageLike ([WildcardPattern]::Escape(
            "No new workflow_dispatch run of '$shown' appeared within 1 s." +
            ' Give a longer -TimeoutSeconds to wait more.')) `
        -Message 'Wait-GitHubWorkflowRunStart shows no credential in the timeout'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
