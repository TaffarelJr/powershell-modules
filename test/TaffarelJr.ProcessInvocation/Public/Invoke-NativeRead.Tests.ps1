#Requires -Version 7.4
using namespace System.IO
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1'
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module $modulePath -Force
. (Join-Path $PSScriptRoot '..' 'ProcessInvocationTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a successful command reports Ok and its output
$result = Invoke-NativeRead -Command $pwsh -Argument @('-NoProfile', '-Command', "Write-Output 'hello'")

# Assert
Assert-That -Condition $result.Ok -Message 'A zero exit code reports Ok'
Assert-Equal -Expected @('hello') -Actual $result.Output -Message 'Output is captured on success too'
Assert-Equal -Expected @() -Actual $result.ErrorOutput -Message 'ErrorOutput is empty unless stderr was kept apart'
Assert-That -Condition (-not $result.TimedOut) -Message 'It did not time out'
Assert-That -Condition $result.Started -Message 'It reports that it started'
Assert-Equal -Expected @('ErrorOutput', 'ExitCode', 'Ok', 'Output', 'Started', 'TimedOut') `
    -Actual @($result.Keys | Sort-Object) `
    -Message 'and the result has exactly these keys'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a failing command is reported, not thrown
$result = Invoke-NativeRead -Command $pwsh -Argument @('-NoProfile', '-Command', 'exit 3')

# Assert
Assert-That -Condition (-not $result.Ok) -Message 'A non-zero exit code reports Ok as false, rather than throwing'
Assert-Equal -Expected 3 -Actual $result.ExitCode `
    -Message 'The real exit code is reported, not just discarded into a boolean'
Assert-That -Condition $result.Started -Message 'and a command that ran and failed still counts as started'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a command that exits with a negative code, which Windows reports as it is, on each route
$negative = Invoke-NativeRead -Command $pwsh -Argument @('-NoProfile', '-Command', 'exit -1')
$negativeDirect = Invoke-NativeRead -Command $pwsh -Argument @('-NoProfile', '-Command', 'exit -1') -TimeoutSeconds 30

# Assert
Assert-That -Condition (-not $negative.Ok) -Message 'A negative exit code reports Ok as false'
Assert-That -Condition (-not $negativeDirect.Ok) -Message 'and so does it on a process of its own'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a command that does not exist is reported, not thrown
$result = Invoke-NativeRead -Command 'this-command-does-not-exist-xyz' -Argument @('x')

# Assert
Assert-That -Condition (-not $result.Ok) `
    -Message 'A command that cannot be started reports Ok as false, rather than throwing'
Assert-That -Condition (-not $result.Started) `
    -Message 'and Started as false, so no caller has to read that from the exit code'
Assert-Equal -Expected 127 -Actual $result.ExitCode -Message 'It reports the shell''s own "command not found" code'
Assert-That -Condition (($result.Output -join ' ') -like '*this-command-does-not-exist-xyz*') `
    -Message 'The output says which command was not found'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a caller who has native failures turned into errors
$PSNativeCommandUseErrorActionPreference = $true

# Act
$result = Invoke-NativeRead -Command $pwsh -Argument @('-NoProfile', '-Command', 'exit 3')
$PSNativeCommandUseErrorActionPreference = $false

# Assert
Assert-That -Condition (-not $result.Ok) `
    -Message 'A caller''s error-action preference does not turn a tolerated failure into a throw'
Assert-Equal -Expected 3 -Actual $result.ExitCode -Message 'The exit code is still reported'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a tolerated failure resets LASTEXITCODE
# so a later check is not fooled
$global:LASTEXITCODE = 0
$null = Invoke-NativeRead -Command $pwsh -Argument @('-NoProfile', '-Command', 'exit 99')

# Assert
Assert-Equal -Expected 0 -Actual $LASTEXITCODE -Message 'LASTEXITCODE is reset to 0 after a tolerated failure'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - an empty-string element in -Argument binds without error
$result = Invoke-NativeRead -Command $pwsh -Argument @('-NoProfile', '-Command', '"[" + $args[0] + "]"', '')

# Assert
Assert-Equal -Expected @('[]') -Actual $result.Output `
    -Message 'An empty-string argument element is accepted and reaches the command as a real, empty argument'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a command that reports how many arguments it got
function global:Get-ArgumentCountProbe { "$($args.Count) arguments" }

# Act
$result = Invoke-NativeRead -Command 'Get-ArgumentCountProbe'
Remove-Item -Path function:global:Get-ArgumentCountProbe

# Assert
Assert-Equal -Expected @('0 arguments') -Actual $result.Output -Message 'A command can be run with no -Argument at all'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same command, and a list that is $null, as a splatted variable that was never set is
function global:Get-ArgumentCountProbe { "$($args.Count) arguments" }
$unset = $null
$splat = @{ Command = 'Get-ArgumentCountProbe'; Argument = $unset }

# Act
$viaNull = Invoke-NativeRead -Command 'Get-ArgumentCountProbe' -Argument $null
$viaSplat = Invoke-NativeRead @splat
Remove-Item -Path function:global:Get-ArgumentCountProbe

# Assert
Assert-Equal -Expected @('0 arguments') -Actual $viaNull.Output -Message 'A $null -Argument is no arguments at all'
Assert-Equal -Expected @('0 arguments') -Actual $viaSplat.Output `
    -Message 'and so is a splatted variable that was never set'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the command and its arguments by position
$result = Invoke-NativeRead $pwsh @('-NoProfile', '-Command', "Write-Output 'positional'")

# Assert
Assert-Equal -Expected @('positional') -Actual $result.Output `
    -Message '-Command and -Argument are positional, in that order'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - -StdIn is piped rather than passed as an argument
$result = Invoke-NativeRead -Command $pwsh -Argument @('-NoProfile', '-Command', '$input') -StdIn 'piped-value'

# Assert
Assert-Equal -Expected @('piped-value') -Actual $result.Output -Message '-StdIn is piped to the command'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - stderr output does not, by itself, make Ok false
$result = Invoke-NativeRead -Command $pwsh `
    -Argument @('-NoProfile', '-Command', "[Console]::Error.WriteLine('chatty but fine'); exit 0")

# Assert
Assert-That -Condition $result.Ok -Message 'stderr output alone does not flip a zero-exit command to failed'
Assert-Equal -Expected @('chatty but fine') -Actual $result.Output `
    -Message 'The stderr content is still present in Output'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - stderr kept apart
$result = Invoke-NativeRead -Command $pwsh `
    -Argument @('-NoProfile', '-Command', "[Console]::Error.WriteLine('to stderr'); Write-Output 'to stdout'") `
    -SeparateStderr

# Assert
Assert-Equal -Expected @('to stdout') -Actual $result.Output -Message '-SeparateStderr keeps stdout alone in Output'
Assert-Equal -Expected @('to stderr') -Actual $result.ErrorOutput -Message 'and returns stderr as ErrorOutput'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$folder = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $folder | Out-Null
try {
    # Act
    $result = Invoke-NativeRead -Command $pwsh -Argument @('-NoProfile', '-Command', '(Get-Location).ProviderPath') `
        -WorkingDirectory $folder

    # Assert
    Assert-Equal -Expected @((Get-Item -LiteralPath $folder).FullName) -Actual $result.Output `
        -Message '-WorkingDirectory is where the command runs'
}
finally {
    Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a working directory that is not there
$result = Invoke-NativeRead -Command $pwsh -Argument @('-NoProfile', '-Command', 'exit 0') `
    -WorkingDirectory (Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid()))

# Assert
Assert-That -Condition (-not $result.Ok) -Message 'A working directory that does not exist is reported, not thrown'
Assert-Equal -Expected 127 -Actual $result.ExitCode -Message 'with the same code as a command that could not start'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a working directory that is not a folder on disk
Assert-Throws `
    -ScriptBlock { Invoke-NativeRead -Command $pwsh -Argument @(
        '-NoProfile', '-Command', 'exit 0'
    ) -WorkingDirectory 'Env:\' } `
    -MessageLike "-WorkingDirectory 'Env:\' is on the Environment provider: give a folder on disk." `
    -Message 'A -WorkingDirectory that is not a folder on disk is refused as the caller''s mistake, not reported'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - an environment for the command alone
$result = Invoke-NativeRead -Command $pwsh -Argument @('-NoProfile', '-Command', '$env:PROBE_READ_ENV') `
    -Environment @{ PROBE_READ_ENV = 'for-the-child' }

# Assert
Assert-Equal -Expected @('for-the-child') -Actual $result.Output -Message '-Environment reaches the command'
Assert-That -Condition ($null -eq $env:PROBE_READ_ENV) -Message 'and does not appear in this process'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a variable this process has
$env:PROBE_READ_REMOVED = 'inherited'
try {
    # Act
    $result = Invoke-NativeRead -Command $pwsh `
        -Argument @('-NoProfile', '-Command', '"[" + $env:PROBE_READ_REMOVED + "]"') `
        -Environment @{ PROBE_READ_REMOVED = $null }
    $own = $env:PROBE_READ_REMOVED
}
finally {
    Remove-Item Env:\PROBE_READ_REMOVED -ErrorAction SilentlyContinue
}

# Assert
Assert-Equal -Expected @('[]') -Actual $result.Output `
    -Message 'A $null -Environment value removes the variable for the command'
Assert-Equal -Expected 'inherited' -Actual $own -Message 'and leaves this process''s alone'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a timeout outside what is allowed
Assert-Throws `
    -ScriptBlock { Invoke-NativeRead -Command $pwsh -Argument @(
        '-NoProfile', '-Command', 'exit 0'
    ) -TimeoutSeconds 0 } `
    -MessageLike "*parameter 'TimeoutSeconds'*" `
    -Message 'A zero -TimeoutSeconds is refused, rather than read as no limit'
Assert-Throws `
    -ScriptBlock { Invoke-NativeRead -Command $pwsh -Argument @(
        '-NoProfile', '-Command', 'exit 0'
    ) -TimeoutSeconds 86401 } `
    -MessageLike "*parameter 'TimeoutSeconds'*" `
    -Message 'and so is one over a day'
#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a command that overruns its timeout, which is long enough
# for it to start and print first
$result = Invoke-NativeRead -Command $pwsh `
    -Argument @('-NoProfile', '-Command', "Write-Output 'got this far'; Start-Sleep -Seconds 120") `
    -TimeoutSeconds 15

# Assert
Assert-That -Condition (-not $result.Ok) -Message 'A timeout reports Ok as false, rather than throwing'
Assert-That -Condition $result.TimedOut -Message 'and says it was a timeout'
Assert-Equal -Expected 124 -Actual $result.ExitCode -Message 'with the code GNU timeout uses'
Assert-That -Condition ($result.Output -contains 'got this far') -Message 'and what the command printed before then'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - many runspaces reading at once, from a console that is not UTF-8
$originalEncoding = [Console]::OutputEncoding
$expected = "cafe-$([char]0xE9)"
# The child writes raw UTF-8 bytes, so what it writes does not itself depend
# on the shared console's code page, which other processes can change under it.
try {
    [Console]::OutputEncoding = [Encoding]::Latin1

    # Act
    $decoded = 1..24 | ForEach-Object -ThrottleLimit 8 -Parallel {
        Import-Module $using:modulePath
        $read = Invoke-NativeRead -Command $using:pwsh -Argument @('-NoProfile', '-Command', $using:emitUtf8)
        $read.Output[0]
    }
    $wrong = @($decoded | Where-Object { $_ -ne $expected })

    # Assert
    Assert-Equal -Expected 0 -Actual $wrong.Count -Message 'Every overlapping call decodes its output as UTF-8'
    Assert-Equal -Expected ([Encoding]::Latin1).CodePage -Actual ([Console]::OutputEncoding).CodePage `
        -Message 'The console encoding is back to what it was once they have all finished'
}
finally {
    [Console]::OutputEncoding = $originalEncoding
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the plural name, accepted as an alias
$aliased = Invoke-NativeRead -Command $pwsh -Arguments @('-NoProfile', '-Command', "Write-Output 'hello'")

# Assert
Assert-Equal -Expected @('hello') -Actual $aliased.Output `
    -Message '-Arguments is an alias of -Argument, and binds the same way'

exit (Complete-TestRun)
