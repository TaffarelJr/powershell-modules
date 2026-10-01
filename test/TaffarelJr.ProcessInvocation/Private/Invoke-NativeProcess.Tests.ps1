#Requires -Version 7.4
using namespace System.Diagnostics
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Text

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Read by the script block or child process the test hands it to, by scope.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ProcessInvocationTestHelper.ps1')
$privatePath = Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/Private'
foreach ($name in 'Find-NativeCommand', 'Stop-NativeProcessTree', 'Invoke-NativeProcess') {
    . (Join-Path $privatePath "$name.ps1")
}
. (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/Public/Hide-UrlCredential.ps1')

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null
$echoArgs = New-EchoArgsScript -Folder $root
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act - a successful command
    $result = Invoke-NativeProcess -Command $pwsh -Arguments @('-NoProfile', '-Command', "Write-Output 'hello'")

    # Assert
    Assert-That -Condition $result.Started -Message 'A command that ran is reported as started'
    Assert-Equal -Expected 0 -Actual $result.ExitCode -Message 'A successful command exits 0'
    Assert-Equal -Expected @('hello') -Actual $result.Output -Message 'Output is the lines it printed'
    Assert-Equal -Expected @() -Actual $result.ErrorOutput -Message 'Nothing is in ErrorOutput when stderr is merged'
    Assert-That -Condition (-not $result.TimedOut) -Message 'It did not time out'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $result = Invoke-NativeProcess -Command $pwsh -Arguments @('-NoProfile', '-Command', 'exit 7')

    # Assert
    Assert-Equal -Expected 7 -Actual $result.ExitCode -Message 'A non-zero exit code is reported, not thrown'
    Assert-That -Condition $result.Started -Message 'A command that ran and failed still counts as started'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $result = Invoke-NativeProcess -Command $pwsh -Arguments @('-NoProfile', '-Command', 'exit 0')

    # Assert
    Assert-Equal -Expected @() -Actual $result.Output -Message 'A silent command gives an empty array, never $null'

    #───────────────────────────────────────────────────────────────────────────
    # Act - stdout and stderr both written, merged
    $result = Invoke-NativeProcess -Command $pwsh `
        -Arguments @('-NoProfile', '-Command', "[Console]::Error.WriteLine('to stderr'); Write-Output 'to stdout'")

    # Assert
    Assert-Equal -Expected @('to stdout', 'to stderr') -Actual $result.Output `
        -Message 'Merged output is all of stdout, then all of stderr'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $result = Invoke-NativeProcess -Command $pwsh `
        -Arguments @('-NoProfile', '-Command', "[Console]::Error.WriteLine('to stderr'); Write-Output 'to stdout'") `
        -SeparateStderr

    # Assert
    Assert-Equal -Expected @('to stdout') -Actual $result.Output -Message '-SeparateStderr keeps stdout alone in Output'
    Assert-Equal -Expected @('to stderr') -Actual $result.ErrorOutput -Message 'and puts stderr in ErrorOutput'

    #───────────────────────────────────────────────────────────────────────────
    # Act - blank lines and a missing final newline
    $result = Invoke-NativeProcess -Command $pwsh `
        -Arguments @('-NoProfile', '-Command', "[Console]::Out.Write(""a``n``nb"")")

    # Assert
    Assert-Equal -Expected @('a', '', 'b') -Actual $result.Output `
        -Message 'A blank line is kept, and a last line without a newline still counts'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $result = Invoke-NativeProcess -Command $pwsh `
        -Arguments @('-NoProfile', '-Command', "[Console]::Out.Write(""a``n``n"")")

    # Assert
    Assert-Equal -Expected @('a', '') -Actual $result.Output `
        -Message 'Only the final newline is dropped, so a trailing blank line survives'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a carriage return on its own, as a progress line uses
    $result = Invoke-NativeProcess -Command $pwsh `
        -Arguments @('-NoProfile', '-Command', "[Console]::Out.Write(""a``rb``r``nc"")")

    # Assert
    Assert-Equal -Expected @('a', 'b', 'c') -Actual $result.Output `
        -Message 'A lone carriage return ends a line, as it does through the call operator'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $expected = ([UTF8Encoding]::new($false).GetBytes('abc' + [Environment]::NewLine) | ForEach-Object { $_.ToString('x2') }) -join ' '

    # Act
    $result = Invoke-NativeProcess -Command $pwsh -Arguments @('-NoProfile', '-Command', $dumpStdIn) -StdIn 'abc'

    # Assert
    Assert-Equal -Expected @($expected) -Actual $result.Output -Message '-StdIn is written, ended with one newline'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $expected = ([UTF8Encoding]::new($false).GetBytes([Environment]::NewLine) | ForEach-Object { $_.ToString('x2') }) -join ' '

    # Act
    $result = Invoke-NativeProcess -Command $pwsh -Arguments @('-NoProfile', '-Command', $dumpStdIn) -StdIn ''

    # Assert
    Assert-Equal -Expected @($expected) -Actual $result.Output -Message 'An empty -StdIn sends just the newline'

    #───────────────────────────────────────────────────────────────────────────
    # Act - no -StdIn at all
    $result = Invoke-NativeProcess -Command $pwsh -Arguments @('-NoProfile', '-Command', $dumpStdIn) -TimeoutSeconds 30

    # Assert
    Assert-Equal -Expected @('') -Actual $result.Output `
        -Message 'Without -StdIn the input is already at its end, with nothing in it'
    Assert-That -Condition (-not $result.TimedOut) -Message 'so a command reading it is not left waiting'

    #───────────────────────────────────────────────────────────────────────────
    # Act - far more input than a pipe holds, to a command that never reads it
    $result = Invoke-NativeProcess -Command $pwsh -Arguments @('-NoProfile', '-NonInteractive', '-Command', 'exit 0') `
        -StdIn ('x' * 65536)

    # Assert
    Assert-That -Condition $result.Started -Message 'Input the command exits without reading is not an error'
    Assert-Equal -Expected 0 -Actual $result.ExitCode -Message 'and the command''s own exit code is reported'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - input that fills the pipe of a command that neither reads it nor
    # ends; it times out whether or not the command has started by then
    $timeout = 3
    $clock = [Stopwatch]::StartNew()

    # Act
    $result = Invoke-NativeProcess -Command $pwsh `
        -Arguments @('-NoProfile', '-NonInteractive', '-Command', 'Start-Sleep -Seconds 120') `
        -StdIn ('x' * 2MB) `
        -TimeoutSeconds $timeout
    $clock.Stop()

    # Assert
    Assert-That -Condition $result.TimedOut `
        -Message 'Writing input the command never reads is bounded by -TimeoutSeconds too'
    Assert-That -Condition ($clock.Elapsed.TotalSeconds -lt 100) `
        -Message 'so the call ends at the deadline, however late a loaded machine makes that, not when the command does'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a console that is not UTF-8, which this function leaves alone
    $originalEncoding = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Encoding]::Latin1

        # Act
        $result = Invoke-NativeProcess -Command $pwsh -Arguments @('-NoProfile', '-Command', $emitUtf8)
        $afterCodePage = [Console]::OutputEncoding.CodePage
    }
    finally {
        [Console]::OutputEncoding = $originalEncoding
    }

    # Assert
    Assert-Equal -Expected @("cafe-$([char]0xE9)") -Actual $result.Output `
        -Message 'Output decodes as UTF-8 whatever the console''s code page'
    Assert-Equal -Expected ([Encoding]::Latin1).CodePage -Actual $afterCodePage `
        -Message 'and the console''s encoding is not touched here'

    #───────────────────────────────────────────────────────────────────────────
    # Act - arguments that need care to survive
    $result = Invoke-NativeProcess -Command $pwsh `
        -Arguments @('-NoProfile', '-File', $echoArgs, 'say "hi"', '', 'a b', 'back\slash')

    # Assert
    Assert-Equal -Expected @('[say "hi"]', '[]', '[a b]', '[back\slash]') -Actual $result.Output `
        -Message 'Quotes, an empty argument, spaces, and backslashes arrive intact'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $folder = Join-Path $root 'work-here'
    New-Item -ItemType Directory -Path $folder | Out-Null

    # Act
    $result = Invoke-NativeProcess -Command $pwsh `
        -Arguments @('-NoProfile', '-Command', '(Get-Location).ProviderPath') `
        -WorkingDirectory $folder

    # Assert
    Assert-Equal -Expected @((Get-Item -LiteralPath $folder).FullName) -Actual $result.Output `
        -Message '-WorkingDirectory is where the command starts'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - PowerShell is in one folder and the process in another
    $here = Join-Path $root 'ps-location'
    $there = Join-Path $root 'process-directory'
    New-Item -ItemType Directory -Path (Join-Path $here 'sub'), $there | Out-Null
    $where = @('-NoProfile', '-Command', '(Get-Location).ProviderPath')

    # Act
    $default = Use-SplitLocation -Location $here -ProcessDirectory $there `
        -ScriptBlock { Invoke-NativeProcess -Command $pwsh -Arguments $where }
    $relative = Use-SplitLocation -Location $here -ProcessDirectory $there `
        -ScriptBlock { Invoke-NativeProcess -Command $pwsh -Arguments $where -WorkingDirectory (Join-Path '.' 'sub') }

    # Assert
    Assert-Equal -Expected @((Get-Item -LiteralPath $here).FullName) -Actual $default.Output `
        -Message 'With no -WorkingDirectory the command starts where PowerShell is, not where the process is'
    Assert-Equal -Expected @((Join-Path (Get-Item -LiteralPath $here).FullName 'sub')) -Actual $relative.Output `
        -Message 'A relative -WorkingDirectory is relative to where PowerShell is'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $env:PROBE_PARENT_ONLY = 'inherited'

    # Act
    $result = Invoke-NativeProcess -Command $pwsh `
        -Arguments @('-NoProfile', '-Command', '"[" + $env:PROBE_CHILD_ONLY + "][" + $env:PROBE_PARENT_ONLY + "]"') `
        -Environment @{ PROBE_CHILD_ONLY = 'for-the-child' }
    $leaked = [Environment]::GetEnvironmentVariable('PROBE_CHILD_ONLY')

    # Assert
    Assert-Equal -Expected @('[for-the-child][inherited]') -Actual $result.Output `
        -Message '-Environment adds to what the command inherits'
    Assert-That -Condition ($null -eq $leaked) -Message 'and never appears in this process'

    #───────────────────────────────────────────────────────────────────────────
    # Act - removing an inherited variable for the child only
    $result = Invoke-NativeProcess -Command $pwsh `
        -Arguments @('-NoProfile', '-Command', '"[" + $env:PROBE_PARENT_ONLY + "]"') `
        -Environment @{ PROBE_PARENT_ONLY = $null }

    # Assert
    Assert-Equal -Expected @('[]') -Actual $result.Output -Message 'A $null value removes the variable for the child'
    Assert-Equal -Expected 'inherited' -Actual $env:PROBE_PARENT_ONLY -Message 'and leaves this process''s alone'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a variable named like a member of the dictionary that holds it
    $result = Invoke-NativeProcess -Command $pwsh `
        -Arguments @('-NoProfile', '-Command', '"[" + $env:Keys + "]"') `
        -Environment @{ Keys = 'for-the-child' }

    # Assert
    Assert-Equal -Expected @('[for-the-child]') -Actual $result.Output `
        -Message '-Environment sets a variable named Keys, not one named for its value'

    #───────────────────────────────────────────────────────────────────────────
    # Act - the same, with a value that holds =, which only a name may not
    $result = Invoke-NativeProcess -Command $pwsh `
        -Arguments @('-NoProfile', '-Command', '"[" + $env:Keys + "]"') `
        -Environment @{ Keys = 'a=b' }

    # Assert
    Assert-Equal -Expected @('[a=b]') -Actual $result.Output `
        -Message 'and a value that holds = is not mistaken for a name'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - names no variable can have
    Assert-Throws `
        -ScriptBlock { Invoke-NativeProcess -Command $pwsh -Arguments @(
            '-NoProfile', '-Command', 'exit 0'
        ) -Environment @{ '' = 'x' } } `
        -MessageLike "-Environment name '' is not a valid variable name*" `
        -Message 'An empty -Environment name is refused as the caller''s mistake, not reported as a command that could not start'
    Assert-Throws `
        -ScriptBlock { Invoke-NativeProcess -Command $pwsh -Arguments @(
            '-NoProfile', '-Command', 'exit 0'
        ) -Environment @{ '  ' = 'x' } } `
        -MessageLike "-Environment name '  ' is not a valid variable name*" `
        -Message 'and so is a blank one'
    Assert-Throws `
        -ScriptBlock { Invoke-NativeProcess -Command $pwsh -Arguments @(
            '-NoProfile', '-Command', 'exit 0'
        ) -Environment @{ 'A=B' = 'x' } } `
        -MessageLike "-Environment name 'A=B' is not a valid variable name*must not*contain '='*" `
        -Message 'and one holding =, which would silently set some other variable'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a command that finishes well inside its timeout
    $result = Invoke-NativeProcess -Command $pwsh -Arguments @('-NoProfile', '-Command', "Write-Output 'quick'") `
        -TimeoutSeconds 60

    # Assert
    Assert-That -Condition (-not $result.TimedOut) -Message 'A command that finishes in time does not time out'
    Assert-Equal -Expected @('quick') -Actual $result.Output -Message 'and its output is intact'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a command that prints, then hangs, with a timeout long enough
    # for it to start and print first, and the slow search for processes
    # the kill missed made visible. The killed process is given a minute to
    # close its pipes, so a machine too busy to do so within the usual two
    # seconds does not change what the case shows.
    $timeout = 15
    $treeStops = [System.Collections.Generic.List[int]]::new()
    function script:Stop-NativeProcessTree {
        param($Process)
        $treeStops.Add($Process.Id)
    }

    $clock = [Stopwatch]::StartNew()

    # Act
    $result = Invoke-NativeProcess -Command $pwsh `
        -Arguments @(
            '-NoProfile', '-Command',
            "[Console]::Out.WriteLine('started'); [Console]::Out.Flush(); Start-Sleep -Seconds 120"
        ) `
        -TimeoutSeconds $timeout -KillGraceMilliseconds 60000
    $clock.Stop()
    . (Join-Path $privatePath 'Stop-NativeProcessTree.ps1')

    # Assert
    Assert-That -Condition $result.TimedOut -Message 'A command still running at the deadline is reported as timed out'
    Assert-Equal -Expected 124 -Actual $result.ExitCode -Message 'with the code GNU timeout uses'
    Assert-Equal -Expected @('started') -Actual $result.Output -Message 'and what it printed before then is kept'
    Assert-Equal -Expected 0 -Actual $treeStops.Count `
        -Message 'It is killed at once, without first searching every process for ones it started'
    Assert-That -Condition ($clock.Elapsed.TotalSeconds -lt 100) `
        -Message 'so the call ends long before the 120 seconds the command would sleep'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a command that leaves a process of its own holding the output
    # pipes, then exits at once, with time to do so before the deadline
    $timeout = 15
    $grandchild = "`$p = Start-Process -FilePath '$pwsh' " +
    "-ArgumentList '-NoProfile', '-Command', 'Start-Sleep -Seconds 120' -NoNewWindow -PassThru; " +
    '[Console]::Out.WriteLine($p.Id); exit 0'
    $clock = [Stopwatch]::StartNew()

    # Act
    $result = Invoke-NativeProcess -Command $pwsh -Arguments @('-NoProfile', '-Command', $grandchild) `
        -TimeoutSeconds $timeout
    $clock.Stop()
    $leftover = $result.Output | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
    $leftover | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction Ignore }

    # Assert
    Assert-That -Condition $result.TimedOut `
        -Message 'Output held open past the deadline by a process the command started counts as a timeout'
    Assert-That -Condition ($clock.Elapsed.TotalSeconds -lt 100) `
        -Message 'so the call ends long before the 120 seconds that process would sleep'
    Assert-Equal -Expected 1 -Actual @($leftover).Count -Message 'and what was printed before then is kept'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a process two generations down whose parent has exited too, so
    # nothing traces it back to the command: it holds the pipes, and survives.
    # Three PowerShells start one after another before the deadline.
    $timeout = 30
    $untraceable = {
        param([string]$Report)
        $encode = { param([string]$Text) [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Text)) }
        $greatGrandchild = "$Report; Start-Sleep -Seconds 120"
        $grandchild = "Start-Process -FilePath '$pwsh' -ArgumentList '-NoProfile', '-EncodedCommand', '$(& $encode $greatGrandchild)' -NoNewWindow"
        "Start-Process -FilePath '$pwsh' -ArgumentList '-NoProfile', '-EncodedCommand', '$(& $encode $grandchild)' -NoNewWindow -Wait"
    }

    $child = & $untraceable '[Console]::Out.WriteLine($PID); [Console]::Out.Flush()'
    $searchedAt = [System.Collections.Generic.List[long]]::new()
    $searchTree = ${function:Stop-NativeProcessTree}
    function script:Stop-NativeProcessTree {
        param($Process)
        $searchedAt.Add($clock.ElapsedMilliseconds)
        & $searchTree -Process $Process
    }

    $clock = [Stopwatch]::StartNew()

    # Act
    $result = Invoke-NativeProcess -Command $pwsh -Arguments @('-NoProfile', '-Command', $child) `
        -TimeoutSeconds $timeout
    $clock.Stop()
    . (Join-Path $privatePath 'Stop-NativeProcessTree.ps1')
    $untraced = $result.Output | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
    $untraced | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction Ignore }

    # Assert
    Assert-That -Condition $result.TimedOut `
        -Message 'Output held open by a process nothing can trace back is still a timeout'
    Assert-That -Condition ($clock.Elapsed.TotalSeconds -lt 100) `
        -Message 'and the call gives up on that output long before the 120 seconds that process would sleep'
    Assert-Equal -Expected 1 -Actual @($untraced).Count -Message 'keeping what was printed before then'
    Assert-Equal -Expected 1 -Actual $searchedAt.Count `
        -Message 'The slow search for processes the kill missed is made once'
    Assert-That -Condition (($searchedAt | Select-Object -First 1) -ge $timeout * 1000 + 2000) `
        -Message 'and not until the killed process has had two seconds to close its pipes'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - something going wrong mid-wait: the search for processes the
    # kill missed, which only output still held open past the deadline reaches
    $pidFile = Join-Path $root 'mid-wait.pid'
    $child = & $untraceable "`$PID | Set-Content -LiteralPath '$pidFile'"
    function script:Stop-NativeProcessTree { throw 'Stopping the tree failed for the test.' }

    # Act / Assert
    Assert-Throws `
        -ScriptBlock { Invoke-NativeProcess -Command $pwsh -Arguments @(
            '-NoProfile', '-Command', $child
        ) -TimeoutSeconds $timeout } `
        -MessageLike 'Stopping the tree failed for the test.' `
        -Message 'A failure while waiting is thrown, not swallowed'
    . (Join-Path $privatePath 'Stop-NativeProcessTree.ps1')
    $untraced = Get-Content -LiteralPath $pidFile -ErrorAction Ignore
    $untraced | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction Ignore }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a call stopped from outside, as Ctrl+C stops it
    $pidFile = Join-Path $root 'stopped.pid'
    $shell = [PowerShell]::Create()
    $null = $shell.AddScript({
            param($PrivatePath, $Pwsh, $PidFile)
            foreach ($name in 'Find-NativeCommand', 'Stop-NativeProcessTree', 'Invoke-NativeProcess') {
                . (Join-Path $PrivatePath "$name.ps1")
            }

            Invoke-NativeProcess -Command $Pwsh `
                -Arguments @(
                    '-NoProfile', '-Command', "`$PID | Set-Content -LiteralPath '$PidFile'; Start-Sleep -Seconds 120"
                )
        }).AddArgument($privatePath).AddArgument($pwsh).AddArgument($pidFile)
    try {
        $running = $shell.BeginInvoke()
        $childId = Wait-ProcessIdFile -Path $pidFile

        # Act
        $clock = [Stopwatch]::StartNew()
        $stopping = $shell.BeginStop($null, $null)
        $stopped = $stopping.AsyncWaitHandle.WaitOne(20000)
        $clock.Stop()
        $stillRunning = Test-ProcessRunning -Id $childId
    }
    finally {
        Stop-Process -Id $childId -Force -ErrorAction Ignore
        $shell.Dispose()
    }

    # Assert
    Assert-That -Condition $stopped -Message 'Stopping the pipeline lands while the command is still running'
    Assert-That -Condition ($clock.Elapsed.TotalSeconds -lt 10) -Message 'within moments, not when the command ends'
    Assert-That -Condition (-not $stillRunning) -Message 'and the command is killed rather than left behind'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $result = Invoke-NativeProcess -Command 'this-command-does-not-exist-xyz' -Arguments @('x')

    # Assert
    Assert-That -Condition (-not $result.Started) -Message 'A command that does not exist is reported as not started'
    Assert-Equal -Expected 127 -Actual $result.ExitCode -Message 'with the shell''s "command not found" code'
    Assert-That -Condition (($result.Output -join ' ') -like '*this-command-does-not-exist-xyz*') `
        -Message 'and a reason naming it'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the path of this very PowerShell, with its last letter a wildcard
    $pattern = $pwsh.Substring(0, $pwsh.Length - 1) + '*'

    # Act
    $result = Invoke-NativeProcess -Command $pattern -Arguments @('-NoProfile', '-Command', 'exit 0')

    # Assert
    Assert-That -Condition (-not $result.Started) `
        -Message 'A wildcard in -Command is part of the name, not a pattern matching some other program'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a PowerShell function, which is not a program
    function global:Get-NotAProgramProbe { 'from a function' }

    # Act
    $result = Invoke-NativeProcess -Command 'Get-NotAProgramProbe'
    Remove-Item -Path function:global:Get-NotAProgramProbe

    # Assert
    Assert-That -Condition (-not $result.Started) -Message 'A function is not run by the direct path'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item Env:\PROBE_PARENT_ONLY -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
