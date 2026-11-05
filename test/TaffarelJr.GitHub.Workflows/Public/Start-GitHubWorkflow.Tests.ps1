#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a dispatch with inputs on a ref; gh 2.87 and later, given no
# terminal, prints only the new run's URL
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/actions/runs/18234567890')
try {
    # Act
    $inputs = @{ version = '1.2.3'; dry_run = 'true' }
    $dispatch = Start-GitHubWorkflow -Workflow 'draft-release.yml' -Ref 'main' -Inputs $inputs -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('workflow', 'run', '--ref=main', '--json', '--repo', 'o/r', '--', 'draft-release.yml')
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'Inputs are not arguments: gh is told to read them as JSON, and the workflow comes last, after a --'
    Assert-Equal -Expected '{"dry_run":"true","version":"1.2.3"}' -Actual $call.StdIn `
        -Message 'and the inputs are one JSON object of strings on its standard input, sorted by name'
    $run = [PSCustomObject]@{
        Url        = 'https://github.com/o/r/actions/runs/18234567890'
        DatabaseId = [long]18234567890
    }
    Assert-Equal -Expected $run -Actual $dispatch -Message 'The new run''s URL is returned, with its id read from it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no inputs, and gh reports no URL (an older gh, or a GitHub that
# does not return the run)
$fake = New-FakeGitHubCli
try {
    # Act
    $dispatch = Start-GitHubWorkflow -Workflow 'ci.yml'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('workflow', 'run', '--', 'ci.yml') -Actual $call.Arguments `
        -Message 'Without options, only the workflow is named'
    Assert-Equal -Expected ([PSCustomObject]@{ Url = $null; DatabaseId = $null }) -Actual $dispatch `
        -Message 'No URL in gh''s output gives an object with neither, so a caller knows to fall back'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a URL that is not a run's
$fake = New-FakeGitHubCli -Output @('https://ghe.example.com/o/r/actions')
try {
    # Act
    $dispatch = Start-GitHubWorkflow -Workflow 'ci.yml'

    # Assert
    Assert-Equal -Expected ([PSCustomObject]@{ Url = 'https://ghe.example.com/o/r/actions'; DatabaseId = $null }) `
        -Actual $dispatch `
        -Message 'A URL with no run id in it is returned without one'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - workflows piped in as Get-GitHubWorkflow returns them, and as text
$fake = New-FakeGitHubCli
try {
    # Act
    @(
        [PSCustomObject]@{ Id = 42; Name = 'CI'; Path = '.github/workflows/ci.yml' }
        [PSCustomObject]@{ Id = 132478870; Name = 'Dependabot Updates'; Path = 'dynamic/dependabot/dependabot-updates' }
        'release.yml'
    ) | Start-GitHubWorkflow | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('workflow', 'run', '--', '42') -Actual $calls[0].Arguments `
        -Message 'A piped workflow is named by its Id'
    Assert-Equal -Expected @('workflow', 'run', '--', '132478870') -Actual $calls[1].Arguments `
        -Message 'so a dynamic workflow, whose Path gh cannot look up, is found too'
    Assert-Equal -Expected @('workflow', 'run', '--', 'release.yml') -Actual $calls[2].Arguments `
        -Message 'and piped text is the workflow itself'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a workflow listed from another repository
$fake = New-FakeGitHubCli
try {
    $workflow = [PSCustomObject]@{ Id = 42; Path = '.github/workflows/ci.yml'; Repository = 'other/repo' }

    # Act
    $workflow | Start-GitHubWorkflow -Ref 'main' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('workflow', 'run', '--ref=main', '--repo', 'other/repo', '--', '42') `
        -Actual $call.Arguments `
        -Message 'A piped workflow is dispatched in the repository it came from'

    # Act
    Start-GitHubWorkflow -Workflow @($workflow) | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[1]

    # Assert
    Assert-Equal -Expected @('workflow', 'run', '--repo', 'other/repo', '--', '42') -Actual $call.Arguments `
        -Message 'A lookup of one workflow wrapped in @() is that workflow, dispatched where it came from'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        $workflow | Start-GitHubWorkflow -Repository 'o/r'
    } -MessageLike 'Workflow 42 is in other/repo, but -Repository names o/r: give one or the other.' `
        -Message 'A -Repository naming another repository throws'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - inputs of every kind a workflow can take, in an ordered dictionary
$fake = New-FakeGitHubCli
try {
    # Act
    $inputs = [ordered]@{
        flag    = $true
        count   = 3
        note    = $null
        text    = 'a=b'
        dry_run = [switch]::new($true)
        quiet   = [switch]::new($false)
    }
    Start-GitHubWorkflow -Workflow 'ci.yml' -Inputs $inputs | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = '{"count":"3","dry_run":"true","flag":"true","note":"","quiet":"false","text":"a=b"}'
    Assert-Equal -Expected @('workflow', 'run', '--json', '--', 'ci.yml') -Actual $call.Arguments `
        -Message 'No input is an argument'
    Assert-Equal -Expected $expected -Actual $call.StdIn `
        -Message 'A bool or a switch goes as true or false, a number as its digits, $null as an empty string'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - inputs that are not one value, and names that are no input's
$refused = @(
    @{
        Inputs  = @{ tags = @('a', 'b') }
        Pattern = 'Input ''tags'' holds `[Object`[`]`], and a workflow input is one value: give text, a number*'
        Message = 'A list input is refused'
    }
    @{
        Inputs  = @{ options = @{ a = 1 } }
        Pattern = 'Input ''options'' holds `[Hashtable`]*'
        Message = 'as is a hashtable input'
    }
    @{
        Inputs  = @{ who = [PSCustomObject]@{ Name = 'x' } }
        Pattern = 'Input ''who'' holds `[PSCustomObject`]*'
        Message = 'and an object input'
    }
    @{
        Inputs  = @{ 'a=b' = 'c' }
        Pattern = '''a=b'' is not a workflow input name: a name starts with a letter or _*'
        Message = 'A name holding = is refused, which gh would split'
    }
    @{ Inputs = @{ '' = 'c' }; Pattern = "'' is not a workflow input name*"; Message = 'as is an empty name' }
    @{ Inputs = @{ '1st' = 'c' }; Pattern = "'1st' is not a workflow input name*"; Message = 'and one led by a digit' }
)
$fake = New-FakeGitHubCli
try {
    foreach ($case in $refused) {
        $inputs = $case.Inputs

        # Act / Assert
        Assert-Throws -ScriptBlock {
            Start-GitHubWorkflow -Workflow 'ci.yml' -Inputs $inputs
        } -MessageLike $case.Pattern -Message $case.Message
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names GitHub accepts
$fake = New-FakeGitHubCli
try {
    # Act
    Start-GitHubWorkflow -Workflow 'ci.yml' -Inputs @{ _private = 'a'; 'log-level' = 'b'; Level2 = 'c' } | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected '{"_private":"a","Level2":"c","log-level":"b"}' -Actual $call.StdIn `
        -Message 'A name may start with _ and hold digits and dashes'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one input named count, with nothing in it
$fake = New-FakeGitHubCli
try {
    # Act
    Start-GitHubWorkflow -Workflow 'ci.yml' -Inputs @{ count = '' } | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('workflow', 'run', '--json', '--', 'ci.yml') -Actual $call.Arguments `
        -Message 'An input named count is an input, not the number of them: gh is still told to read JSON'
    Assert-Equal -Expected '{"count":""}' -Actual $call.StdIn -Message 'and receives it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that JSON must escape, and an empty set of inputs
$fake = New-FakeGitHubCli
try {
    # Act
    $text = "say `"hi`"`nback\slash é ✓"
    Start-GitHubWorkflow -Workflow 'ci.yml' -Inputs @{ note = $text } | Out-Null
    Start-GitHubWorkflow -Workflow 'ci.yml' -Inputs @{} | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected '{"note":"say \"hi\"\nback\\slash é ✓"}' -Actual $calls[0].StdIn `
        -Message 'A quote, a line break, a backslash, and characters beyond ASCII reach gh as valid JSON'
    Assert-Equal -Expected @('workflow', 'run', '--', 'ci.yml') -Actual $calls[1].Arguments `
        -Message 'No inputs at all adds neither --json nor anything on standard input'
    Assert-Equal -Expected '' -Actual $calls[1].StdIn -Message 'so gh is not sent an empty object'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an input far too large for a command line
$fake = New-FakeGitHubCli
try {
    # Act
    $large = 'x' * 200000
    Start-GitHubWorkflow -Workflow 'ci.yml' -Inputs @{ blob = $large } | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('workflow', 'run', '--json', '--', 'ci.yml') -Actual $call.Arguments `
        -Message 'A large input is no part of the command line, which has a limit'
    Assert-Equal -Expected "{`"blob`":`"$large`"}" -Actual $call.StdIn -Message 'it all arrives on standard input'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an input value that must not be seen: in -Verbose output, and in the message of a failure
$fake = New-FakeGitHubCli -ErrorOutput @('HTTP 422: Workflow does not have ''workflow_dispatch'' trigger') -ExitCode 1
try {
    # Act
    $failure = try {
        Start-GitHubWorkflow -Workflow 'ci.yml' -Inputs @{ token = 'INPUT_SENTINEL' }
    }
    catch {
        $_.Exception.Message
    }

    # Assert
    Assert-That -Condition ($failure -like '*Dispatching workflow ci.yml failed*') `
        -Message 'A failing dispatch says what it was doing'
    Assert-That -Condition ($failure -notlike '*INPUT_SENTINEL*') -Message 'without showing an input value'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

$fake = New-FakeGitHubCli
try {
    # Act
    $lines = @(Start-GitHubWorkflow -Workflow 'ci.yml' -Inputs @{ token = 'INPUT_SENTINEL' } -Verbose 4>&1 |
            Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } |
            ForEach-Object Message)

    # Assert
    $expected = @(
        'Performing the operation "Dispatch workflow" on target "workflow ci.yml".'
        'Dispatching workflow ci.yml: gh workflow run --json -- ci.yml (with standard input)'
    )
    Assert-Equal -Expected $expected -Actual $lines `
        -Message '-Verbose says what it does, then the command line, with the inputs on standard input and not in it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a workflow that looks like an option, and one that is $null
$fake = New-FakeGitHubCli
try {
    # Act
    Start-GitHubWorkflow -Workflow '--web' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('workflow', 'run', '--', '--web') -Actual $call.Arguments `
        -Message 'A workflow is an operand whatever it starts with'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Start-GitHubWorkflow -Workflow $null
    } -MessageLike "*Workflow*null*" -Message 'A $null workflow is refused'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a ref given blank, as a variable that came back empty gives it
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Start-GitHubWorkflow -Workflow 'ci.yml' -Ref ''
    } -MessageLike '-Ref is blank: give a branch or tag, or leave it out for the default branch.' `
        -Message 'A blank -Ref is refused, not taken for the default branch'
    Assert-Throws -ScriptBlock {
        Start-GitHubWorkflow -Workflow 'ci.yml' -Ref ' '
    } -MessageLike '-Ref is blank: give a branch or tag, or leave it out for the default branch.' `
        -Message 'as is one of spaces'

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the workflow has no workflow_dispatch trigger
$fake = New-FakeGitHubCli -ErrorOutput @('HTTP 422: Workflow does not have ''workflow_dispatch'' trigger') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Start-GitHubWorkflow -Workflow 'ci.yml'
    } -MessageLike '*Dispatching workflow ci.yml failed*does not have*workflow_dispatch*' `
        -Message 'A failure throws with the message from gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with every other parameter, and with workflows piped in;
# gh would report the run it started
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/actions/runs/18234567890')
try {
    $inputs = @{ version = 'INPUT_SENTINEL'; dry_run = $true }
    $origin = 'https://user:SENTINEL@github.com/a/b'
    $workflows = @([PSCustomObject]@{ Id = 1; Path = '.github/workflows/a.yml'; Repository = $origin }, 'b.yml')

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Start-GitHubWorkflow -Workflow 'ci.yml' -Ref 'main' -Inputs $inputs -Repository 'o/r' -WhatIf
        $workflows | Start-GitHubWorkflow -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Dispatch workflow on main" on target "o/r workflow ci.yml".'
        'What if: Performing the operation "Dispatch workflow" on target "a/b workflow 1".'
        'What if: Performing the operation "Dispatch workflow" on target "workflow b.yml".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages `
        -Message '-WhatIf names each workflow and its ref'
    Assert-Equal -Expected @() -Actual @($whatIf.Messages -match 'SENTINEL') `
        -Message 'and shows neither an input value nor a token'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is never called: nothing is dispatched'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'and no run is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/actions/runs/18234567890')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Start-GitHubWorkflow -Workflow 'ci.yml' -Inputs @{ 'bad name' = 'x' } -WhatIf
    } -MessageLike "'bad name' is not a workflow input name:*" `
        -Message 'With -WhatIf, a bad input name is still refused'
    Assert-Throws -ScriptBlock {
        Start-GitHubWorkflow -Workflow 'ci.yml' -Ref ' ' -WhatIf
    } -MessageLike '-Ref is blank: give a branch or tag, or leave it out for the default branch.' `
        -Message 'as is a blank -Ref'

    # Act
    $dispatch = Start-GitHubWorkflow -Workflow 'ci.yml' -Ref 'main' -Repository 'o/r' -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('workflow', 'run', '--ref=main', '--repo', 'o/r', '--', 'ci.yml') `
        -Actual $call.Arguments `
        -Message '-Confirm:$false runs the change, and adds nothing to gh''s arguments'
    Assert-Equal -Expected ([long]18234567890) -Actual $dispatch.DatabaseId -Message 'and returns the run'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
