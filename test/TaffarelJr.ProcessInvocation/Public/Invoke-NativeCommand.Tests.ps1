#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ProcessInvocationTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a successful command writes its output to the pipeline
$result = Invoke-NativeCommand -Activity 'Testing' -Command $pwsh `
    -Argument @('-NoProfile', '-Command', "Write-Output 'hello'")

# Assert
Assert-Equal -Expected 'hello' -Actual $result `
    -Message 'A single line of output comes back as that line, as a native command''s would'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - several lines, piped straight on
$piped = Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument @(
    '-NoProfile', '-Command', "Write-Output 'a'; Write-Output 'b'"
) | Measure-Object

# Assert
Assert-Equal -Expected 2 -Actual $piped.Count `
    -Message 'Each line is its own pipeline item, so the call pipes straight into another command'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a command that fails, with arguments that need quoting to read back
function global:Invoke-FailingProbe { $global:LASTEXITCODE = 7 }

# Act / Assert
Assert-Throws `
    -ScriptBlock { Invoke-NativeCommand -Activity 'Testing' -Command 'Invoke-FailingProbe' -Argument @(
        '-Plain', 'two words', '', "it's", 'say "hi"'
    ) } `
    -MessageLike "Testing failed: Invoke-FailingProbe -Plain 'two words' '' 'it''s' 'say `"hi`"' (exit 7)" `
    -Message 'The thrown message names the activity, the command line quoted so it can be copied back out, and the exit code'

Remove-Item -Path function:global:Invoke-FailingProbe

#───────────────────────────────────────────────────────────────────────────────
# Arrange - arguments PowerShell would read as code if pasted back bare, among
# ordinary ones that read back as they are
function global:Invoke-FailingProbe { $global:LASTEXITCODE = 7 }
$arguments = @(
    'a;b', '$x', 'x,y', '#c', '{b}', '(p)', '@s', '--%', "it$([char]0x2019)s", "$([char]0x2018)x$([char]0x201B)",
    "abc`n", '--json', '-c', 'C:\x\y.txt', '--limit=5', 'user@host', '100%'
)
$typographic = "'it$([char]0x2019)$([char]0x2019)s' '$([char]0x2018)$([char]0x2018)x$([char]0x201B)$([char]0x201B)' 'abc`n'"

# Act / Assert
Assert-Throws `
    -ScriptBlock { Invoke-NativeCommand -Activity 'Testing' -Command 'Invoke-FailingProbe' -Argument $arguments } `
    -MessageLike "Testing failed: Invoke-FailingProbe 'a;b' '`$x' 'x,y' '#c' '{b}' '(p)' '@s' '--%' $typographic --json -c C:\x\y.txt --limit=5 user@host 100% (exit 7)" `
    -Message 'Every argument holding a character PowerShell would act on is quoted, a trailing newline and a typographic single quote included, and only those'

Remove-Item -Path function:global:Invoke-FailingProbe

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a command whose name needs quoting, which pasted back would then be
# a string rather than a call
Set-Item -Path 'function:global:Invoke Failing Probe' -Value { $global:LASTEXITCODE = 7 }

# Act / Assert
Assert-Throws `
    -ScriptBlock { Invoke-NativeCommand -Activity 'Testing' -Command 'Invoke Failing Probe' -Argument @('x') } `
    -MessageLike "Testing failed: & 'Invoke Failing Probe' x (exit 7)" `
    -Message 'A quoted command is preceded by the call operator, so the line still runs it'

Remove-Item -LiteralPath 'function:global:Invoke Failing Probe'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - the thrown message includes the command's own output as detail
Assert-Throws `
    -ScriptBlock { Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument @(
        '-NoProfile', '-Command', "Write-Output 'useful detail'; exit 1"
    ) } `
    -MessageLike '*useful detail*' `
    -Message 'The failure message includes the command''s own output'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a command that does not exist
Assert-Throws `
    -ScriptBlock { Invoke-NativeCommand -Activity 'Looking up' -Command 'this-command-does-not-exist-xyz' -Argument @('x') } `
    -MessageLike 'Looking up failed:*', '*could not run*this-command-does-not-exist-xyz*' `
    -Message 'A command that cannot be started names the activity and the command, and says it could not be run'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a command that exits with a negative code, which Windows reports as it is, on each route
Assert-Throws `
    -ScriptBlock { Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument @(
        '-NoProfile', '-Command', 'exit -1'
    ) } `
    -MessageLike 'Testing failed:*(exit *)*' `
    -Message 'A negative exit code is a failure, not only a positive one'
Assert-Throws `
    -ScriptBlock { Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument @(
        '-NoProfile', '-Command', 'exit -1'
    ) -TimeoutSeconds 30 } `
    -MessageLike 'Testing failed:*(exit *)*' `
    -Message 'and so is it on a process of its own'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a silent success
$bare = Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument @('-NoProfile', '-Command', 'exit 0')
$collected = @(Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument @('-NoProfile', '-Command', 'exit 0'))

# Assert
Assert-That -Condition ($null -eq $bare) -Message 'A silent success writes nothing, so a bare capture is $null'
Assert-Equal -Expected @() -Actual $collected -Message 'and wrapping the call in @() collects an empty array'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - an empty-string element in -Argument binds without error
$result = @(Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument @('-NoProfile', '-Command', '"[" + $args[0] + "]"', ''))

# Assert
Assert-Equal -Expected @('[]') -Actual $result `
    -Message 'An empty-string argument element is accepted and reaches the command as a real, empty argument'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a command that reports how many arguments it got
function global:Get-ArgumentCountProbe { "$($args.Count) arguments" }

# Act
$result = @(Invoke-NativeCommand -Activity 'Testing' -Command 'Get-ArgumentCountProbe')
Remove-Item -Path function:global:Get-ArgumentCountProbe

# Assert
Assert-Equal -Expected @('0 arguments') -Actual $result -Message 'A command can be run with no -Argument at all'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same command, and a list that is $null, as a splatted variable that was never set is
function global:Get-ArgumentCountProbe { "$($args.Count) arguments" }
$unset = $null
$splat = @{ Activity = 'Testing'; Command = 'Get-ArgumentCountProbe'; Argument = $unset }

# Act
$viaNull = @(Invoke-NativeCommand -Activity 'Testing' -Command 'Get-ArgumentCountProbe' -Argument $null)
$viaSplat = @(Invoke-NativeCommand @splat)
Remove-Item -Path function:global:Get-ArgumentCountProbe

# Assert
Assert-Equal -Expected @('0 arguments') -Actual $viaNull -Message 'A $null -Argument is no arguments at all'
Assert-Equal -Expected @('0 arguments') -Actual $viaSplat -Message 'and so is a splatted variable that was never set'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the command and its arguments by position, the activity by name
$result = @(Invoke-NativeCommand $pwsh @('-NoProfile', '-Command', "Write-Output 'positional'") -Activity 'Testing')

# Assert
Assert-Equal -Expected @('positional') -Actual $result -Message '-Command and -Argument are positional, in that order'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - -StdIn is piped rather than exposed as an argument
$result = @(Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument @('-NoProfile', '-Command', '$input') -StdIn 'a-secret-value')

# Assert
Assert-Equal -Expected @('a-secret-value') -Actual $result -Message '-StdIn reaches the command via its input stream'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - stderr kept out of what is returned
$result = @(Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument @('-NoProfile', '-Command', "[Console]::Error.WriteLine('warning: noise'); Write-Output '{""a"":1}'") -SeparateStderr)

# Assert
Assert-Equal -Expected @('{"a":1}') -Actual $result `
    -Message '-SeparateStderr returns only stdout, so a warning cannot end up in what is parsed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - stderr still explains a failure when it was kept apart
Assert-Throws `
    -ScriptBlock { Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument @(
        '-NoProfile', '-Command', "[Console]::Error.WriteLine('the real reason'); exit 2"
    ) -SeparateStderr } `
    -MessageLike '*the real reason*' `
    -Message 'A failure''s message includes stderr even when it was kept apart'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$folder = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $folder | Out-Null
try {
    # Act
    $result = @(Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument @('-NoProfile', '-Command', '(Get-Location).ProviderPath') -WorkingDirectory $folder)

    # Assert
    Assert-Equal -Expected @((Get-Item -LiteralPath $folder).FullName) -Actual $result `
        -Message '-WorkingDirectory is where the command runs'
}
finally {
    Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a working directory that is not a folder on disk
Assert-Throws `
    -ScriptBlock { Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument @(
        '-NoProfile', '-Command', 'exit 0'
    ) -WorkingDirectory 'Env:\' } `
    -MessageLike "-WorkingDirectory 'Env:\' is on the Environment provider: give a folder on disk." `
    -Message 'A -WorkingDirectory that is not a folder on disk is refused with a message naming its provider'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - PowerShell is in one folder and the process in another
$here = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
$there = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $here, $there | Out-Null
try {
    $where = @('-NoProfile', '-Command', '(Get-Location).ProviderPath')

    # Act - the same command, with and without options that need a process of its own
    $plain = @(Use-SplitLocation -Location $here -ProcessDirectory $there -ScriptBlock { Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument $where })
    $timed = @(Use-SplitLocation -Location $here -ProcessDirectory $there -ScriptBlock { Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument $where -TimeoutSeconds 30 })
    $withEnvironment = @(Use-SplitLocation -Location $here -ProcessDirectory $there -ScriptBlock { Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument $where -Environment @{ PROBE_X = '1' } })

    # Assert
    Assert-Equal -Expected @((Get-Item -LiteralPath $here).FullName) -Actual $plain `
        -Message 'A command runs where PowerShell is'
    Assert-Equal -Expected $plain -Actual $timed -Message 'and asking for a -TimeoutSeconds does not move it'
    Assert-Equal -Expected $plain -Actual $withEnvironment -Message 'nor does asking for an -Environment'
}
finally {
    Remove-Item -LiteralPath $here, $there -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - an environment for the command alone
$result = @(Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument @('-NoProfile', '-Command', '$env:PROBE_COMMAND_ENV') -Environment @{ PROBE_COMMAND_ENV = 'for-the-child' })

# Assert
Assert-Equal -Expected @('for-the-child') -Actual $result -Message '-Environment reaches the command'
Assert-That -Condition ($null -eq $env:PROBE_COMMAND_ENV) -Message 'and does not appear in this process'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a command that overruns its timeout, which is long
# enough for it to start and print first
Assert-Throws `
    -ScriptBlock { Invoke-NativeCommand -Activity 'Waiting' -Command $pwsh -Argument @(
        '-NoProfile', '-Command', "Write-Output 'got this far'; Start-Sleep -Seconds 120"
    ) -TimeoutSeconds 15 } `
    -MessageLike 'Waiting failed:*', '*timed out after 15 seconds*', '*got this far*' `
    -Message 'A timeout throws, naming the activity and the limit, and keeping what the command had printed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a leftover exit code from an earlier failure
$global:LASTEXITCODE = 5

# Act - a successful call on a process of its own
$null = Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument @('-NoProfile', '-Command', 'exit 0') `
    -TimeoutSeconds 30

# Assert
Assert-Equal -Expected 0 -Actual $global:LASTEXITCODE -Message 'A success leaves $LASTEXITCODE at 0 on every route'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a timeout outside what is allowed
Assert-Throws `
    -ScriptBlock { Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument @(
        '-NoProfile', '-Command', 'exit 0'
    ) -TimeoutSeconds 0 } `
    -MessageLike "*parameter 'TimeoutSeconds'*" `
    -Message 'A zero -TimeoutSeconds is refused, rather than read as no limit'
Assert-Throws `
    -ScriptBlock { Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument @(
        '-NoProfile', '-Command', 'exit 0'
    ) -TimeoutSeconds 86401 } `
    -MessageLike "*parameter 'TimeoutSeconds'*" `
    -Message 'and so is one over a day'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the plural name, accepted as an alias
$aliased = Invoke-NativeCommand -Activity 'Testing' -Command $pwsh `
    -Arguments @('-NoProfile', '-Command', "Write-Output 'hello'")

# Assert
Assert-Equal -Expected 'hello' -Actual $aliased -Message '-Arguments is an alias of -Argument, and binds the same way'

exit (Complete-TestRun)
