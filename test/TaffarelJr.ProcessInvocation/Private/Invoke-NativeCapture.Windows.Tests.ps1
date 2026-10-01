#Requires -Version 7.4
using namespace System.IO

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
. (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/Public/Hide-UrlCredential.ps1')

# Batch files, a console of one's own to hide, and a program every install
# has are all Windows things.
if (-not $IsWindows) {
    exit (Skip-TestRun -Reason 'batch files, hidden consoles and System32 are Windows-only')
}

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a real console, and a child that asks a question on it
    $ask = '[Console]::Out.Write(''Continue? [y/N] ''); $a = [Console]::In.ReadLine(); "answer=<$a> null=$($null -eq $a)"'
    $script = @"
`$ask = '$($ask.Replace("'", "''"))'
`$viaOperator = Invoke-NativeRead -Command '$pwsh' -Arguments @('-NoProfile', '-Command', `$ask)
`$viaProcess = Invoke-NativeRead -Command '$pwsh' -Arguments @('-NoProfile', '-Command', `$ask) -TimeoutSeconds 30
"operator: `$(`$viaOperator.Output)"
"process: `$(`$viaProcess.Output)"
"@

    # Act
    $run = Invoke-HiddenConsoleScript -Script $script -TimeoutSeconds 90

    # Assert
    Assert-That -Condition $run.Finished `
        -Message 'A command that reads its input does not wait on the console it would otherwise inherit'
    Assert-Equal `
        -Expected @('operator: Continue? [y/N] answer=<> null=True', 'process: Continue? [y/N] answer=<> null=True') `
        -Actual $run.Output `
        -Message 'It reads the end of its input at once, through the call operator and through a process of its own'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a real console, and a child that reads its input as text: it
    # decodes with the console's input code page, so the text is five
    # characters (three, and the line end) only when that is UTF-8
    $script = @"
`$text = [Text.Encoding]::UTF8.GetString([byte[]](0x68, 0xC3, 0xA9, 0xC3, 0xA9))
`$read = '[Console]::In.ReadToEnd().Length'
`$viaOperator = Invoke-NativeRead -Command '$pwsh' -Argument @('-NoProfile', '-Command', `$read) -StdIn `$text
`$viaProcess = Invoke-NativeRead -Command '$pwsh' -Argument @('-NoProfile', '-Command', `$read) -StdIn `$text ``
    -TimeoutSeconds 30
"operator: `$(`$viaOperator.Output)"
"process: `$(`$viaProcess.Output)"
"@

    # Act
    $run = Invoke-HiddenConsoleScript -Script $script -TimeoutSeconds 90

    # Assert
    Assert-That -Condition $run.Finished -Message 'A command that reads text from -StdIn finishes'
    Assert-Equal -Expected @('operator: 5', 'process: 5') -Actual $run.Output `
        -Message 'It decodes the UTF-8 it is sent as UTF-8, through the call operator and through a process of its own'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a batch file that shows its first three arguments
    $batch = Join-Path $root 'show-args.cmd'
    [File]::WriteAllText($batch, "@echo off`r`necho 1=[%~1] 2=[%~2] 3=[%~3]`r`n")

    # Act
    $viaOperator = Invoke-NativeCapture -Command $batch -Arguments @('a', '', 'c')
    $viaProcess = Invoke-NativeCapture -Command $batch -Arguments @('a', '', 'c') -TimeoutSeconds 30

    # Assert
    Assert-Equal -Expected @('1=[a] 2=[c] 3=[]') -Actual $viaOperator.Output `
        -Message 'Through the call operator a batch file loses an empty argument, as the help warns'
    Assert-Equal -Expected @('1=[a] 2=[] 3=[c]') -Actual $viaProcess.Output `
        -Message 'and through a process of its own it keeps it'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a program in a folder whose name holds wildcard characters
    $bracketed = Join-Path $root 'br[1]'
    New-Item -ItemType Directory -Path $bracketed | Out-Null
    $program = Join-Path $bracketed 'say-hi.cmd'
    [File]::WriteAllText($program, "@echo hi`r`n")

    # Act
    $viaOperator = Invoke-NativeCapture -Command $program
    $viaProcess = Invoke-NativeCapture -Command $program -TimeoutSeconds 30

    # Assert
    Assert-Equal -Expected @('hi') -Actual $viaOperator.Output `
        -Message 'A path with brackets in it runs through the call operator'
    Assert-Equal -Expected @('hi') -Actual $viaProcess.Output `
        -Message 'and through a process of its own, taken literally rather than as a pattern'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a program that takes no arguments
    $hostname = Join-Path ([Environment]::SystemDirectory) 'hostname.exe'

    # Act
    $withEmpty = Invoke-NativeCapture -Command $hostname -Arguments @() -TimeoutSeconds 30
    $omitted = Invoke-NativeCapture -Command $hostname -TimeoutSeconds 30

    # Assert
    Assert-Equal -Expected 0 -Actual $withEmpty.ExitCode `
        -Message 'An empty -Arguments array runs a program bare on the direct path'
    Assert-Equal -Expected $withEmpty.Output -Actual $omitted.Output -Message 'and leaving -Arguments out does the same'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
