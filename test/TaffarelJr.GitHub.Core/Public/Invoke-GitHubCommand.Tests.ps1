#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a fake gh that answers with two lines
$fake = New-FakeGitHubCli -Output @('first', 'second')
try {
    # Act
    $out = Invoke-GitHubCommand -Activity 'Listing' -Argument @('pr', 'list') -Repository 'owner/repo'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('first', 'second') -Actual $out -Message "gh's output lines are returned"
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'gh is invoked exactly once'
    Assert-Equal -Expected @('pr', 'list', '--repo', 'owner/repo') -Actual $calls[0].Arguments `
        -Message '-Repository is appended as --repo after the given arguments'
    Assert-Equal -Expected '' -Actual $calls[0].StdIn -Message 'Nothing is piped to gh without -StdIn'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - arguments with a -- ahead of their operands
$fake = New-FakeGitHubCli
try {
    # Act
    Invoke-GitHubCommand -Activity 'Searching' -Argument @(
        'search', 'issues', '--json', 'number', '--', '-label:bug'
    ) -Repository 'owner/repo' | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('search', 'issues', '--json', 'number', '--repo', 'owner/repo', '--', '-label:bug') `
        -Actual $calls[0].Arguments `
        -Message '--repo goes ahead of the --, since after it gh would read it as an operand'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a -- that is the first argument
$fake = New-FakeGitHubCli
try {
    # Act
    Invoke-GitHubCommand -Activity 'Running' -Argument @('--', 'x') -Repository 'owner/repo' | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('--repo', 'owner/repo', '--', 'x') -Actual $calls[0].Arguments `
        -Message '--repo still goes first when the -- does'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one line of output, no -Repository
$fake = New-FakeGitHubCli -Output @('only')
try {
    # Act
    $out = Invoke-GitHubCommand -Activity 'Reading' -Argument @('auth', 'token')
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 'only' -Actual $out -Message 'A single output line is written as that line'
    Assert-Equal -Expected @('auth', 'token') -Actual $calls[0].Arguments `
        -Message 'Without -Repository, no --repo is added'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository object, as a listing returns one
$fake = New-FakeGitHubCli
$repository = [PSCustomObject]@{ Name = 'repo'; NameWithOwner = 'owner/repo'; StargazerCount = 7 }
try {
    # Act
    Invoke-GitHubCommand -Activity 'Listing' -Argument @('pr', 'list') -Repository $repository | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('pr', 'list', '--repo', 'owner/repo') -Actual $calls[0].Arguments `
        -Message 'A repository object is read as ConvertTo-GitHubRepositoryReference reads it, not as its text'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock { Invoke-GitHubCommand -Activity 'Listing' -Argument @('pr', 'list') -Repository ' ' } `
        -MessageLike '-Repository is blank: give OWNER/REPO, HOST/OWNER/REPO, or a URL.' `
        -Message 'A blank -Repository is refused rather than read as the current directory''s'

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is run'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a value that must only ever travel on stdin
$fake = New-FakeGitHubCli
try {
    # Act
    Invoke-GitHubCommand -Activity 'Setting' -Argument @('secret', 'set', 'NAME') -StdIn 'hunter2' | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 'hunter2' -Actual $calls[0].StdIn -Message '-StdIn reaches gh on its standard input'
    Assert-That -Condition ($calls[0].Arguments -notcontains 'hunter2') `
        -Message 'The piped value never appears among the arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh fails
$fake = New-FakeGitHubCli -Output @('boom') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Invoke-GitHubCommand -Activity 'Creating' -Argument @('pr', 'create')
    } -MessageLike '*Creating failed: gh pr create (exit 1)*boom*' `
        -Message 'A non-zero exit throws by default, naming the activity, the call, the exit code, and what gh said'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh fails, but the caller asked to tolerate that
$fake = New-FakeGitHubCli -Output @('not found') -ExitCode 1
try {
    # Act
    $result = Invoke-GitHubCommand -Activity 'Probing' -Argument @('api', 'repos/o/r') -Tolerant

    # Assert
    Assert-Equal -Expected $false -Actual $result.Ok `
        -Message '-Tolerant reports a failure as Ok = $false instead of throwing'
    Assert-Equal -Expected 1 -Actual $result.ExitCode -Message "-Tolerant carries gh's exit code"
    Assert-Equal -Expected @('not found') -Actual $result.Output -Message "-Tolerant keeps gh's output"
    Assert-Equal -Expected 0 -Actual $LASTEXITCODE -Message 'A tolerated failure does not leave $LASTEXITCODE behind'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a tolerated call that also carries a value on stdin
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Invoke-GitHubCommand -Activity 'Probing' -Argument @('secret', 'set', 'NAME') -StdIn 'hunter2' -Tolerant
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 'hunter2' -Actual $calls[0].StdIn `
        -Message '-StdIn reaches gh on its standard input under -Tolerant too'
    Assert-That -Condition $result.Ok -Message 'The tolerated call still reports its result'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a fake gh that writes a notice to stderr beside its answer
$fake = New-FakeGitHubCli -Output @('{"a":1}') -ErrorOutput @('warning: a notice')
try {
    # Act
    $out = Invoke-GitHubCommand -Activity 'Reading' -Argument @('api', 'x')
    $result = Invoke-GitHubCommand -Activity 'Reading' -Argument @('api', 'x') -Tolerant

    # Assert
    Assert-Equal -Expected '{"a":1}' -Actual $out `
        -Message 'Only stdout comes back, so a notice cannot end up in what is parsed'
    Assert-Equal -Expected @('{"a":1}') -Actual $result.Output `
        -Message 'A tolerated call keeps stdout apart from stderr too'
    Assert-Equal -Expected @('warning: a notice') -Actual $result.ErrorOutput -Message 'and returns stderr on its own'
    Assert-Equal -Expected "{`"a`":1}`nwarning: a notice" -Actual $result.Message `
        -Message 'and both together, for an error to quote'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a fake gh that fails the way gh does: a JSON body on stdout, the reason on stderr
$fake = New-FakeGitHubCli -Output @('{"message":"Not Found"}') -ErrorOutput @('gh: Not Found (HTTP 404)') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Invoke-GitHubCommand -Activity 'Reading the repo' -Argument @('api', 'repos/o/missing')
    } -MessageLike '*Reading the repo failed*(exit 1)*Not Found (HTTP 404)*' `
        -Message 'A failure''s message carries what gh said on stderr'

    # Act
    $failed = Invoke-GitHubCommand -Activity 'x' -Argument @('api', 'x') -Tolerant

    # Assert
    Assert-Equal -Expected $false -Actual $failed.Ok -Message 'A tolerated failure is a result, not a throw'
    Assert-Equal -Expected 1 -Actual $failed.ExitCode -Message 'with gh''s exit code'
    Assert-That -Condition ($failed.Message -like '*Not Found (HTTP 404)*') -Message 'and a Message to quote'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh refusing a flag: its reason, a blank line, then its whole usage text
$usage = @(
    'unknown flag: --nope', '', 'Makes an authenticated HTTP request.', '', 'USAGE', '  gh api <endpoint> [flags]'
)
$fake = New-FakeGitHubCli -ErrorOutput $usage -ExitCode 1
try {
    # Act
    $refused = Invoke-GitHubCommand -Activity 'Calling' -Argument @('api', 'x', '--nope') -Tolerant

    # Assert
    Assert-Equal -Expected 'unknown flag: --nope' -Actual $refused.Message `
        -Message 'The usage text after gh''s reason is left out of the message'
    Assert-Equal -Expected $usage -Actual $refused.ErrorOutput -Message 'while ErrorOutput keeps all of it'
    Assert-Throws -ScriptBlock {
        Invoke-GitHubCommand -Activity 'Calling' -Argument @('api', 'x', '--nope')
    } -MessageLike "*Calling failed: gh api x --nope (exit 1)`nunknown flag: --nope" `
        -Message 'and a thrown message ends with the reason'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - stderr shapes around a usage block, and the message each keeps
$shapes = @(
    @{
        ErrorOutput = @('', 'unknown flag: --x', '', 'Usage: gh x [flags]')
        Expected = 'unknown flag: --x'
        Message = 'A bare usage block is cut at the blank line just above it, so a reason after an opening blank line is kept'
    }
    @{
        ErrorOutput = @('! warning: config', '', 'unknown flag: --x', '', 'Usage: gh x [flags]')
        Expected = "! warning: config`n`nunknown flag: --x"
        Message = 'and so is a warning paragraph before the reason'
    }
    @{
        ErrorOutput = @('', 'unknown flag: --x', '', 'Does a thing.', '', 'USAGE', '  gh x')
        Expected = 'unknown flag: --x'
        Message = 'gh''s whole help is cut after the first paragraph, an opening blank line skipped'
    }
    @{
        ErrorOutput = @('unknown flag: --x', 'USAGE', '  gh x')
        Expected = "unknown flag: --x`nUSAGE`n  gh x"
        Message = 'A usage line with no blank line above it is not cut at all'
    }
)

foreach ($shape in $shapes) {
    $fake = New-FakeGitHubCli -ErrorOutput $shape.ErrorOutput -ExitCode 1
    try {
        # Act / Assert
        $result = Invoke-GitHubCommand -Activity 'Calling' -Argument @('x') -Tolerant
        Assert-Equal -Expected $shape.Expected -Actual $result.Message -Message $shape.Message
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a failing call whose arguments hold a space, a quote, and an empty one
$fake = New-FakeGitHubCli -ErrorOutput @('bad') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Invoke-GitHubCommand -Activity 'Searching' -Argument @('search', 'two words', "it's", '')
    } -MessageLike "Searching failed: gh search 'two words' 'it''s' '' (exit 1)*bad" `
        -Message 'The failed call is quoted so it reads back as the arguments it was'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an error of several paragraphs, with no usage text after it
$fake = New-FakeGitHubCli -ErrorOutput @('first paragraph', '', 'second paragraph') -ExitCode 1
try {
    # Act
    $paragraphs = Invoke-GitHubCommand -Activity 'Calling' -Argument @('api', 'x') -Tolerant

    # Assert
    Assert-Equal -Expected "first paragraph`n`nsecond paragraph" -Actual $paragraphs.Message `
        -Message 'Every paragraph is kept, and a blank line stays blank'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a fake gh that also answers a call run as a process of its own
$fake = New-FakeGitHubCli -Output @('from the process') -RecordEnvironment @('GH_EDITOR', 'GH_FAKE_UNSET')
try {
    # Act
    $env:GH_FAKE_UNSET = 'set in the caller'
    $out = Invoke-GitHubCommand -Activity 'Editing' -Argument @('gist', 'edit', 'abc') `
        -Environment @{ GH_EDITOR = 'no-editor'; GH_FAKE_UNSET = $null }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 'from the process' -Actual $out `
        -Message '-Environment runs gh as its own process and returns its output'
    Assert-Equal -Expected @('gist', 'edit', 'abc') -Actual $calls[0].Arguments -Message 'with the same arguments'
    Assert-Equal -Expected 'no-editor' -Actual $calls[0].Environment['GH_EDITOR'] `
        -Message 'and the variables given set for gh alone'
    Assert-Equal -Expected $null -Actual $calls[0].Environment['GH_FAKE_UNSET'] -Message 'a $null one removed for it'
    Assert-Equal -Expected 'set in the caller' -Actual $env:GH_FAKE_UNSET -Message 'while this process keeps its own'
    Assert-Equal -Expected $false -Actual $calls[0].StdInPiped -Message 'and gh reads no input'
}
finally {
    Remove-Item -LiteralPath Env:GH_FAKE_UNSET -ErrorAction SilentlyContinue
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a tolerated call, for the shape of its result
$fake = New-FakeGitHubCli -Output @('x')
try {
    # Act
    $shape = Invoke-GitHubCommand -Activity 'Reading' -Argument @('api', 'x') -Tolerant

    # Assert
    Assert-Equal -Expected @('ErrorOutput', 'ExitCode', 'Message', 'Ok', 'Output', 'Started', 'TimedOut') `
        -Actual @($shape.PSBase.Keys | Sort-Object) `
        -Message 'A tolerated result carries exactly the keys its help lists'
    Assert-Equal -Expected $true -Actual $shape.Started -Message 'Started says gh ran'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a machine with no gh on its PATH
$savedPath = $env:PATH
$env:PATH = ''
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Invoke-GitHubCommand -Activity 'Reading' -Argument @('auth', 'status') -Tolerant
    } -MessageLike '*Reading failed: gh was not found on PATH*' `
        -Message 'A tolerated call says gh is missing, rather than answering as if the thing asked about were not there'
    Assert-Throws -ScriptBlock {
        Invoke-GitHubCommand -Activity 'Reading' -Argument @('auth', 'status')
    } -MessageLike '*Reading failed*gh*' -Message 'and so does an untolerated one'
}
finally {
    $env:PATH = $savedPath
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the plural name -Argument had before, which stays an alias
$fake = New-FakeGitHubCli -Output @('ok')
try {
    # Act
    Invoke-GitHubCommand -Activity 'Reading' -Arguments @('api', 'x') | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]
    $aliases =(Get-Command -Name Invoke-GitHubCommand).Parameters['Argument'].Aliases

    # Assert
    Assert-Equal -Expected @('api', 'x') -Actual $call.Arguments -Message '-Arguments still binds the arguments'
    Assert-Equal -Expected @('Arguments') -Actual @($aliases) -Message 'as the alias of -Argument'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
