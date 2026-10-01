#Requires -Version 7.4
using namespace System.IO
using namespace System.Text

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidOverwritingBuiltInCmdlets',
    '',
    Justification = 'One case counts the program lookups with a stand-in that hands on to the real command.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ProcessInvocationTestHelper.ps1')
foreach ($name in 'Get-ConsoleEncodingGate', 'Enter-Utf8Console', 'Exit-Utf8Console',
    'Assert-BatchFileArgument', 'Find-NativeCommand', 'Stop-NativeProcessTree',
    'Invoke-NativeProcess', 'Invoke-NativeCapture') {
    . (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/Private' "$name.ps1")
}
. (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/Private/ConvertTo-MaskList.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/Public/Hide-MaskedValue.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/Public/Hide-UrlCredential.ps1')

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null
$echoArgs = New-EchoArgsScript -Folder $root
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a successful command
    $result = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', "Write-Output 'hello'")

    # Assert
    Assert-That -Condition $result.Started -Message 'A command that ran is reported as started'
    Assert-Equal -Expected 0 -Actual $result.ExitCode -Message 'A successful command reports exit code 0'
    Assert-Equal -Expected @('hello') -Actual $result.Output -Message 'Output is what the command printed, as an array'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a failing command is reported, not thrown
    $result = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', 'exit 7')

    # Assert
    Assert-Equal -Expected 7 -Actual $result.ExitCode -Message 'A non-zero exit code is reported, not thrown'
    Assert-That -Condition $result.Started -Message 'A command that ran and failed still counts as started'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a command that prints nothing still returns an array, not $null
    $result = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', 'exit 0')

    # Assert
    Assert-Equal -Expected @() -Actual $result.Output -Message 'A silent command returns an empty array, never $null'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - stdout and stderr, written apart in time
    $interleaved = "[Console]::Out.WriteLine('o1'); [Console]::Out.Flush(); Start-Sleep -Milliseconds 500; " +
    "[Console]::Error.WriteLine('e1'); [Console]::Error.Flush(); Start-Sleep -Milliseconds 500; [Console]::Out.WriteLine('o2')"
    $result = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', $interleaved)

    # Assert
    Assert-Equal -Expected @('o1', 'e1', 'o2') -Actual $result.Output `
        -Message 'stderr is merged into the output in the order the lines arrived'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $blankLine = "[Console]::Error.WriteLine('first'); [Console]::Error.WriteLine(''); [Console]::Error.WriteLine('third')"

    # Act - a blank line on stderr, merged and kept apart
    $merged = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', $blankLine)
    $separate = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', $blankLine) -SeparateStderr

    # Assert
    Assert-Equal -Expected @('first', '', 'third') -Actual $merged.Output `
        -Message 'A blank stderr line stays blank in merged output, not the name of an exception type'
    Assert-Equal -Expected @('first', '', 'third') -Actual $separate.ErrorOutput -Message 'and in ErrorOutput'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - -StdIn is piped to the command rather than passed as an argument
    $result = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', '$input') -StdIn 'piped-value'

    # Assert
    Assert-Equal -Expected @('piped-value') -Actual $result.Output -Message '-StdIn is piped to the command'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the exact bytes a command receives
    $expected = ([UTF8Encoding]::new($false).GetBytes('abc' + [Environment]::NewLine) | ForEach-Object { $_.ToString('x2') }) -join ' '

    # Act
    $result = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', $dumpStdIn) -StdIn 'abc'

    # Assert
    Assert-Equal -Expected @($expected) -Actual $result.Output `
        -Message '-StdIn is ended with one newline, the platform''s own'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $expected = ([UTF8Encoding]::new($false).GetBytes([Environment]::NewLine) | ForEach-Object { $_.ToString('x2') }) -join ' '

    # Act
    $result = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', $dumpStdIn) -StdIn ''

    # Assert
    Assert-Equal -Expected @($expected) -Actual $result.Output -Message 'An empty -StdIn sends just the newline'

    #───────────────────────────────────────────────────────────────────────────
    # Act - no -StdIn at all
    $result = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', $dumpStdIn)

    # Assert
    Assert-Equal -Expected @('') -Actual $result.Output `
        -Message 'Without -StdIn the command reads nothing (this process''s own input is no console, so only Invoke-NativeCapture.Windows.Tests shows it is not handed one)'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a caller whose profile chose an encoding for piped input
    $expected = ([UTF8Encoding]::new($false).GetBytes("caf$([char]0xE9)" + [Environment]::NewLine) | ForEach-Object { $_.ToString('x2') }) -join ' '
    $callerEncoding = $global:OutputEncoding
    try {
        # Act
        $global:OutputEncoding = [Encoding]::UTF8
        $withBom = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', $dumpStdIn) `
            -StdIn "caf$([char]0xE9)"
        $global:OutputEncoding = [Encoding]::ASCII
        $ascii = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', $dumpStdIn) `
            -StdIn "caf$([char]0xE9)"
    }
    finally {
        $global:OutputEncoding = $callerEncoding
    }

    # Assert
    Assert-Equal -Expected @($expected) -Actual $withBom.Output `
        -Message 'A caller''s UTF-8-with-BOM $OutputEncoding puts no byte-order mark in front of -StdIn'
    Assert-Equal -Expected @($expected) -Actual $ascii.Output `
        -Message 'and a caller''s ASCII one does not turn a non-ASCII character into ?'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - output decodes as UTF-8 regardless of the console's own encoding,
    # and that encoding is restored afterward rather than left pinned to UTF-8
    $originalEncoding = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Encoding]::Latin1
        $result = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', $emitUtf8)
        $afterCodePage = [Console]::OutputEncoding.CodePage
    }
    finally {
        [Console]::OutputEncoding = $originalEncoding
    }

    # Assert
    Assert-Equal -Expected @("cafe-$([char]0xE9)") -Actual $result.Output `
        -Message 'Non-ASCII output decodes correctly regardless of the inherited console encoding'
    Assert-Equal -Expected ([Encoding]::Latin1).CodePage -Actual $afterCodePage `
        -Message 'The console encoding is restored to what it was before the call, not left pinned to UTF-8'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a child that encodes to the console's code page, as most do,
    # under a console that is not UTF-8
    $expected = "caf$([char]0xE9) $([char]0x2500)"
    $originalEncoding = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Encoding]::Latin1

        # Act
        $viaOperator = Invoke-NativeCapture -Command $pwsh `
            -Arguments @('-NoProfile', '-Command', "Write-Output '$expected'")
        $viaProcess = Invoke-NativeCapture -Command $pwsh `
            -Arguments @('-NoProfile', '-Command', "Write-Output '$expected'") `
            -TimeoutSeconds 30
        $afterCodePage = [Console]::OutputEncoding.CodePage
    }
    finally {
        [Console]::OutputEncoding = $originalEncoding
    }

    # Assert
    Assert-Equal -Expected @($expected) -Actual $viaOperator.Output `
        -Message 'What the child encodes itself comes back intact through the call operator'
    Assert-Equal -Expected @($expected) -Actual $viaProcess.Output -Message 'and through a process of its own'
    Assert-Equal -Expected ([Encoding]::Latin1).CodePage -Actual $afterCodePage `
        -Message 'and the console''s encoding is put back after either'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - an empty-string element in -Arguments is accepted and
    # reaches the command as a real, empty argument
    $result = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', '"[" + $args[0] + "]"', '')

    # Assert
    Assert-Equal -Expected @('[]') -Actual $result.Output `
        -Message 'An empty-string argument element reaches the command as a real, empty argument'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a command that reports how many arguments it got
    function global:Get-ArgumentCountProbe { "$($args.Count) arguments" }

    # Act - an empty array, and no -Arguments at all
    $withEmpty = Invoke-NativeCapture -Command 'Get-ArgumentCountProbe' -Arguments @()
    $omitted = Invoke-NativeCapture -Command 'Get-ArgumentCountProbe'
    Remove-Item -Path function:global:Get-ArgumentCountProbe

    # Assert
    Assert-Equal -Expected @('0 arguments') -Actual $withEmpty.Output `
        -Message 'An empty -Arguments array runs the command bare'
    Assert-Equal -Expected @('0 arguments') -Actual $omitted.Output -Message 'Leaving -Arguments out runs it bare too'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a function run as the command, with no -StdIn, that counts what
    # reaches it through the pipeline
    function global:Get-InputCountProbe { "$(@($input).Count) input items" }
    Set-Alias -Name 'gicp' -Value 'Get-InputCountProbe' -Scope Global

    # Act
    $direct = Invoke-NativeCapture -Command 'Get-InputCountProbe' -Arguments @()
    $viaAlias = Invoke-NativeCapture -Command 'gicp' -Arguments @()
    Remove-Alias -Name 'gicp' -Scope Global
    Remove-Item -Path function:global:Get-InputCountProbe

    # Assert
    Assert-Equal -Expected @('0 input items') -Actual $direct.Output `
        -Message 'A function run as the command gets no pipeline input without -StdIn, not one $null'
    Assert-Equal -Expected @('0 input items') -Actual $viaAlias.Output `
        -Message 'and neither does one reached through an alias'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a function that requires pipeline input, named directly and
    # through an alias, run where nothing can prompt for it and with errors
    # stopping, as in the module
    $requiredInput = {
        param($PrivatePath, $Name)
        $ErrorActionPreference = 'Stop'
        foreach ($file in 'Get-ConsoleEncodingGate', 'Enter-Utf8Console', 'Exit-Utf8Console',
            'Assert-BatchFileArgument', 'Find-NativeCommand', 'Stop-NativeProcessTree',
            'Invoke-NativeProcess', 'Invoke-NativeCapture') {
            . (Join-Path $PrivatePath "$file.ps1")
        }

        function Get-RequiredInputProbe {
            param(
                [Parameter(Mandatory, ValueFromPipeline)]
                [string]$Value
            )

            process { "got [$Value]" }
        }

        Set-Alias -Name 'grip' -Value 'Get-RequiredInputProbe'
        Invoke-NativeCapture -Command $Name -Arguments @()
    }

    $rows = @(
        @{
            Name = 'Get-RequiredInputProbe'
            Message = 'and one that requires it fails as it would called directly, rather than binding an empty value'
        }
        @{ Name = 'grip'; Message = 'and so does one run through an alias' }
    )

    # Act / Assert
    foreach ($row in $rows) {
        $shell = [PowerShell]::Create()
        $null = $shell.AddScript($requiredInput).AddArgument((Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/Private')).AddArgument($row.Name)
        try {
            Assert-Throws -ScriptBlock { $shell.Invoke() } -MessageLike '*missing mandatory parameters: Value*' `
                -Message $row.Message
        }
        finally {
            $shell.Dispose()
        }
    }

    #───────────────────────────────────────────────────────────────────────────
    # Act - a command that does not exist, with and without arguments
    $withArgument = Invoke-NativeCapture -Command 'this-command-does-not-exist-xyz' -Arguments @('x')
    $bare = Invoke-NativeCapture -Command 'this-command-does-not-exist-xyz' -Arguments @()

    # Assert
    Assert-That -Condition (-not $withArgument.Started) `
        -Message 'A command that does not exist is reported as not started, not thrown'
    Assert-Equal -Expected 127 -Actual $withArgument.ExitCode `
        -Message 'Not started is the shell''s own "command not found" code'
    Assert-That -Condition (($withArgument.Output -join ' ') -like '*this-command-does-not-exist-xyz*') `
        -Message 'The output says which command was not found'
    Assert-That -Condition (-not $bare.Started) `
        -Message 'The same holds for a bare call, which is what the lookup actually sees'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a name with a wildcard in it, which Get-Date answers to as a pattern, on each route
    $viaOperator = Invoke-NativeCapture -Command 'Get-Dat*' -Arguments @()
    $viaProcess = Invoke-NativeCapture -Command 'Get-Dat*' -Arguments @() -TimeoutSeconds 30

    # Assert
    Assert-That -Condition (-not $viaOperator.Started) `
        -Message ('A wildcard in -Command is part of the name,' +
            ' not a pattern that runs another command, through the call operator')
    Assert-That -Condition (-not $viaProcess.Started) -Message 'and through a process of its own'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a leftover exit code from some earlier native call, and a
    # command that is a function, which never sets one of its own
    function global:Get-FunctionCommandProbe { 'from a function' }
    $global:LASTEXITCODE = 9

    # Act
    $result = Invoke-NativeCapture -Command 'Get-FunctionCommandProbe' -Arguments @()
    Remove-Item -Path function:global:Get-FunctionCommandProbe

    # Assert
    Assert-Equal -Expected 0 -Actual $result.ExitCode -Message 'A stale $LASTEXITCODE is not read as the command''s own'
    Assert-Equal -Expected @('from a function') -Actual $result.Output -Message 'The function ran'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a leftover exit code
    $global:LASTEXITCODE = 5

    # Act - a successful call on each route, each after the leftover code
    $null = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', 'exit 0')
    $afterOperator = $global:LASTEXITCODE
    $global:LASTEXITCODE = 5
    $null = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', 'exit 0') -TimeoutSeconds 30
    $afterProcess = $global:LASTEXITCODE
    $null = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', 'exit 4') -TimeoutSeconds 30
    $afterFailure = $global:LASTEXITCODE

    # Assert
    Assert-Equal -Expected 0 -Actual $afterOperator `
        -Message 'The call operator leaves $LASTEXITCODE holding the command''s exit code'
    Assert-Equal -Expected 0 -Actual $afterProcess `
        -Message 'and so does a process of its own, so no stale code survives a success'
    Assert-Equal -Expected 4 -Actual $afterFailure -Message 'nor hides a failure'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a caller who has native failures turned into errors
    $PSNativeCommandUseErrorActionPreference = $true

    # Act
    $result = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', 'exit 3')
    $PSNativeCommandUseErrorActionPreference = $false

    # Assert
    Assert-Equal -Expected 3 -Actual $result.ExitCode `
        -Message 'A caller''s error-action preference does not turn a reported failure into a throw'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a caller who has legacy native argument passing
    Set-Variable -Name PSNativeCommandArgumentPassing -Value 'Legacy' -Scope Local

    # Act
    $result = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-File', $echoArgs, 'say "hi"', '', 'a b')
    Remove-Variable -Name PSNativeCommandArgumentPassing -Scope Local

    # Assert
    Assert-Equal -Expected @('[say "hi"]', '[]', '[a b]') -Actual $result.Output `
        -Message 'A caller''s argument-passing preference does not drop empty arguments or strip quotes'

    #───────────────────────────────────────────────────────────────────────────
    # Act - stderr kept apart, through the call operator
    $merged = Invoke-NativeCapture -Command $pwsh `
        -Arguments @('-NoProfile', '-Command', "[Console]::Error.WriteLine('to stderr'); Write-Output 'to stdout'")
    $separate = Invoke-NativeCapture -Command $pwsh `
        -Arguments @('-NoProfile', '-Command', "[Console]::Error.WriteLine('to stderr'); Write-Output 'to stdout'") `
        -SeparateStderr

    # Assert
    Assert-Equal -Expected 2 -Actual $merged.Output.Count -Message 'Merged, both streams are in Output'
    Assert-Equal -Expected @() -Actual $merged.ErrorOutput -Message 'and ErrorOutput is empty'
    Assert-Equal -Expected @('to stdout') -Actual $separate.Output `
        -Message '-SeparateStderr leaves only stdout in Output'
    Assert-Equal -Expected @('to stderr') -Actual $separate.ErrorOutput -Message 'and stderr in ErrorOutput'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $folder = Join-Path $root 'work-here'
    New-Item -ItemType Directory -Path $folder | Out-Null
    $before = (Get-Location).ProviderPath

    # Act
    $result = Invoke-NativeCapture -Command $pwsh `
        -Arguments @('-NoProfile', '-Command', '(Get-Location).ProviderPath') `
        -WorkingDirectory $folder
    $after = (Get-Location).ProviderPath

    # Assert
    Assert-Equal -Expected @((Get-Item -LiteralPath $folder).FullName) -Actual $result.Output `
        -Message '-WorkingDirectory is where the command runs'
    Assert-Equal -Expected $before -Actual $after -Message 'and the caller''s own location is put back'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - PowerShell is in one folder and the process in another
    $here = Join-Path $root 'ps-location'
    $there = Join-Path $root 'process-directory'
    New-Item -ItemType Directory -Path (Join-Path $here 'sub'), $there | Out-Null
    $where = @('-NoProfile', '-Command', '(Get-Location).ProviderPath')
    $sub = Join-Path '.' 'sub'
    $expectedHere = @((Get-Item -LiteralPath $here).FullName)
    $expectedSub = @((Join-Path (Get-Item -LiteralPath $here).FullName 'sub'))

    # Act - once through the call operator, once through a process of its own
    $viaOperator = Use-SplitLocation -Location $here -ProcessDirectory $there `
        -ScriptBlock { Invoke-NativeCapture -Command $pwsh -Arguments $where }
    $viaProcess = Use-SplitLocation -Location $here -ProcessDirectory $there `
        -ScriptBlock { Invoke-NativeCapture -Command $pwsh -Arguments $where -TimeoutSeconds 30 }
    $relativeOperator = Use-SplitLocation -Location $here -ProcessDirectory $there `
        -ScriptBlock { Invoke-NativeCapture -Command $pwsh -Arguments $where -WorkingDirectory $sub }
    $relativeProcess = Use-SplitLocation -Location $here -ProcessDirectory $there `
        -ScriptBlock { Invoke-NativeCapture -Command $pwsh -Arguments $where -WorkingDirectory $sub -TimeoutSeconds 30 }

    # Assert
    Assert-Equal -Expected $expectedHere -Actual $viaOperator.Output `
        -Message 'The call operator runs the command where PowerShell is'
    Assert-Equal -Expected $expectedHere -Actual $viaProcess.Output `
        -Message 'and so does a process of its own, rather than where the process happens to be'
    Assert-Equal -Expected $expectedSub -Actual $relativeOperator.Output `
        -Message 'A relative -WorkingDirectory is relative to PowerShell''s location on the call operator route'
    Assert-Equal -Expected $expectedSub -Actual $relativeProcess.Output -Message 'and on the process route'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $result = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', 'exit 0') `
        -WorkingDirectory (Join-Path $root 'no-such-folder')

    # Assert
    Assert-That -Condition (-not $result.Started) `
        -Message 'A working directory that does not exist is reported as not started'
    Assert-Equal -Expected 127 -Actual $result.ExitCode -Message 'with the same code as a missing command'
    Assert-That -Condition (($result.Output -join ' ') -like '*Working directory not found*no-such-folder*') `
        -Message 'and a reason naming the folder'

    #───────────────────────────────────────────────────────────────────────────
    # Act - an environment goes to the direct path, and stays out of this process
    $result = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', '$env:PROBE_CAPTURE_ENV') `
        -Environment @{ PROBE_CAPTURE_ENV = 'set-for-the-child' }

    # Assert
    Assert-Equal -Expected @('set-for-the-child') -Actual $result.Output -Message '-Environment reaches the command'
    Assert-That -Condition ($null -eq $env:PROBE_CAPTURE_ENV) -Message 'and not this process'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a timeout goes to the direct path too
    $result = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-Command', 'Start-Sleep -Seconds 120') `
        -TimeoutSeconds 3

    # Assert
    Assert-That -Condition $result.Started -Message 'A command that overran its timeout was started'
    Assert-That -Condition $result.TimedOut -Message '-TimeoutSeconds kills a command that overruns it'
    Assert-Equal -Expected 124 -Actual $result.ExitCode -Message 'with the timeout exit code'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a leftover exit code, then a direct call that cannot start
    $global:LASTEXITCODE = 5

    # Act
    $result = Invoke-NativeCapture -Command 'this-command-does-not-exist-xyz' -TimeoutSeconds 30

    # Assert
    Assert-That -Condition (-not $result.Started) `
        -Message 'A missing command on the direct path is reported as not started'
    Assert-Equal -Expected 0 -Actual $global:LASTEXITCODE `
        -Message 'and leaves no stale $LASTEXITCODE behind, as on the call operator route'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a program that prints its own raw command line, the comment
    # keeping the arguments after it out of the command it runs
    $showCommandLine = @('-NoProfile', '-Command', 'Write-Output ([Environment]::CommandLine) #', '--%', 'a')

    # Act / Assert - the stop-parsing token as an argument, through the call operator
    Assert-Throws -ScriptBlock { Invoke-NativeCapture -Command $pwsh -Arguments $showCommandLine } `
        -MessageLike "Argument 4 is '--%', which PowerShell drops from a program's arguments through the call operator*-TimeoutSeconds or -Environment*" `
        -Message 'A --% argument to a program is refused through the call operator, which would silently drop it'

    # Act - and through a process of its own
    $result = Invoke-NativeCapture -Command $pwsh -Arguments $showCommandLine -TimeoutSeconds 30

    # Assert
    Assert-That -Condition ($result.Output[0] -like '* --% a') -Message 'and a process of its own passes it as it is'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a function, which gets a --% argument like any other
    function global:Get-ArgumentListProbe { $args -join '|' }

    # Act
    $result = Invoke-NativeCapture -Command 'Get-ArgumentListProbe' -Arguments @('--%', 'a')
    Remove-Item -Path function:global:Get-ArgumentListProbe

    # Assert
    Assert-Equal -Expected @('--%|a') -Actual $result.Output `
        -Message 'A function run as the command gets a --% argument, so it is not refused'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a script named relatively that exists only in the working
    # directory, not where PowerShell is
    $elsewhere = Join-Path $root 'script-elsewhere'
    $scripts = Join-Path $root 'script-here'
    New-Item -ItemType Directory -Path $elsewhere, $scripts | Out-Null
    [File]::WriteAllText((Join-Path $scripts 'join-args.ps1'), '$args -join "|"')

    # Act
    Push-Location -LiteralPath $elsewhere
    try {
        $result = Invoke-NativeCapture -Command (Join-Path '.' 'join-args.ps1') -Arguments @('--%', 'a') `
            -WorkingDirectory $scripts
    }
    finally {
        Pop-Location
    }

    # Assert
    Assert-Equal -Expected @('--%|a') -Actual $result.Output `
        -Message 'A script found in -WorkingDirectory is known there as a script, so its --% argument is not refused'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $result = Invoke-NativeCapture -Command 'this-command-does-not-exist-xyz' -Arguments @('--%', 'a')

    # Assert
    Assert-That -Condition (-not $result.Started) `
        -Message 'A missing command with a --% argument is reported as not started, not refused for the argument'
    Assert-Equal -Expected 127 -Actual $result.ExitCode -Message 'with the shell''s "command not found" code'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a working directory that is a container, but not a folder
    # on disk, on each route
    foreach ($row in @(
            @{ Path = 'Env:\'; Provider = 'Environment' }
            @{ Path = 'Function:\'; Provider = 'Function' }
        )) {
        Assert-Throws `
            -ScriptBlock { Invoke-NativeCapture -Command $pwsh -Arguments @(
                '-NoProfile', '-Command', 'exit 0'
            ) -WorkingDirectory $row.Path } `
            -MessageLike "-WorkingDirectory '$($row.Path)' is on the $($row.Provider) provider: give a folder on disk." `
            -Message "A -WorkingDirectory on the $($row.Provider) provider is refused through the call operator, naming the provider"
        Assert-Throws `
            -ScriptBlock { Invoke-NativeCapture -Command $pwsh -Arguments @(
                '-NoProfile', '-Command', 'exit 0'
            ) -WorkingDirectory $row.Path -TimeoutSeconds 30 } `
            -MessageLike "-WorkingDirectory '$($row.Path)' is on the $($row.Provider) provider: give a folder on disk." `
            -Message 'and through a process of its own'
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a stand-in that counts the lookups of programs, which cost tens of milliseconds each
    $script:programLookups = 0
    function Get-Command {
        if ($args -contains 'Application') {
            $script:programLookups++
        }

        Microsoft.PowerShell.Core\Get-Command @args
    }

    # Act
    try {
        $result = Invoke-NativeCapture -Command $pwsh `
            -Arguments @('-NoProfile', '-Command', 'exit 0') `
            -TimeoutSeconds 30
    }
    finally {
        Remove-Item -Path function:Get-Command
    }

    # Assert
    Assert-Equal -Expected 0 -Actual $result.ExitCode -Message 'A program run on a process of its own still runs'
    Assert-Equal -Expected 1 -Actual $script:programLookups `
        -Message 'and is looked up once, not again by the process that runs it'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
