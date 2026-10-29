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

# Only Windows hands a batch file's arguments to cmd.exe to parse again.
if (-not $IsWindows) {
    exit (Skip-TestRun -Reason 'batch files and cmd.exe are Windows-only')
}

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null
$batch = Join-Path $root 'show-args.cmd'
[File]::WriteAllText($batch, "@echo off`r`necho 1=[%~1] 2=[%~2]`r`n")
$echoArgs = New-EchoArgsScript -Folder $root
$marker = Join-Path $root 'injected'
# One row per refused character; where the character alone can make cmd.exe
# act, the row tries to create the marker with it.
$refused = @(
    @{ Character = '"'; Argument = 'say "hi"' }
    @{ Character = '&'; Argument = "x&mkdir $marker" }
    @{ Character = '|'; Argument = "x|mkdir $marker" }
    @{ Character = '<'; Argument = 'x<nul' }
    @{ Character = '>'; Argument = "x>$marker" }
    @{ Character = '^'; Argument = 'a^b' }
    @{ Character = '%'; Argument = '%PATH%' }
    @{ Character = 'a single %'; Argument = '100%' }
)
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - each character cmd.exe would act on, on each route
    foreach ($row in $refused) {
        Assert-Throws -ScriptBlock { Invoke-NativeCapture -Command $batch -Arguments @('safe', $row.Argument) } `
            -MessageLike "Argument 2 for the batch file '$batch' holds one of*cmd.exe*run commands, redirect, or expand variables*real .exe*-StdIn, -Environment, or a file*" `
            -Message "An argument holding $($row.Character) is refused for a batch file through the call operator, naming its position"
        Assert-Throws `
            -ScriptBlock { Invoke-NativeCapture -Command $batch -Arguments @(
                'safe', $row.Argument
            ) -TimeoutSeconds 30 } `
            -MessageLike "Argument 2 for the batch file '$batch' holds one of*" `
            -Message "and through a process of its own"
    }

    # Assert
    Assert-That -Condition (-not (Test-Path -LiteralPath $marker)) `
        -Message 'and nothing ran: no refused argument reached cmd.exe'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the same batch file under the other extension cmd.exe runs
    $dotBat = Join-Path $root 'show-bat-args.bat'
    Copy-Item -LiteralPath $batch -Destination $dotBat

    # Act / Assert
    foreach ($row in $refused) {
        Assert-Throws -ScriptBlock { Invoke-NativeCapture -Command $dotBat -Arguments @('safe', $row.Argument) } `
            -MessageLike "Argument 2 for the batch file '$dotBat' holds one of*" `
            -Message "An argument holding $($row.Character) is refused for a .bat file through the call operator"
        Assert-Throws `
            -ScriptBlock { Invoke-NativeCapture -Command $dotBat -Arguments @(
                'safe', $row.Argument
            ) -TimeoutSeconds 30 } `
            -MessageLike "Argument 2 for the batch file '$dotBat' holds one of*" `
            -Message 'and through a process of its own'
    }

    # Assert
    Assert-That -Condition (-not (Test-Path -LiteralPath $marker)) `
        -Message 'and nothing ran: no refused argument reached cmd.exe through the .bat file either'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a batch file named relatively that exists only in the working
    # directory, not where PowerShell is
    $elsewhere = Join-Path $root 'elsewhere'
    $workHere = Join-Path $root 'work-here'
    New-Item -ItemType Directory -Path $elsewhere, $workHere | Out-Null
    [File]::WriteAllText((Join-Path $workHere 'only-here.cmd'), "@echo off`r`necho ARGS: %*`r`n")
    $relative = Join-Path '.' 'only-here.cmd'
    $rows = @(
        @{
            Argument = "x&mkdir $marker"
            Message = 'A relative batch file in -WorkingDirectory is checked there, so an argument holding & is refused through the call operator'
        }
        @{ Argument = '%COMPUTERNAME%'; Message = 'and so is one that would expand a variable' }
    )

    Push-Location -LiteralPath $elsewhere
    try {
        # Act / Assert
        foreach ($row in $rows) {
            Assert-Throws `
                -ScriptBlock { Invoke-NativeCapture -Command $relative -Arguments @($row.Argument) -WorkingDirectory $workHere } `
                -MessageLike "Argument 1 for the batch file '$(Join-Path $workHere 'only-here.cmd')' holds one of*" `
                -Message $row.Message
        }

        Assert-Throws `
            -ScriptBlock { Invoke-NativeCapture -Command $relative -Arguments @("x&mkdir $marker") -WorkingDirectory $workHere -TimeoutSeconds 30 } `
            -MessageLike "Argument 1 for the batch file '$(Join-Path $workHere 'only-here.cmd')' holds one of*" `
            -Message 'and through a process of its own, which runs the same file'
        Assert-Throws `
            -ScriptBlock { Invoke-NativeCapture -Command (Join-Path '..' 'work-here' 'only-here.cmd') -Arguments @("x&mkdir $marker") } `
            -MessageLike "Argument 1 for the batch file '*only-here.cmd' holds one of*" `
            -Message 'as it is without -WorkingDirectory, named relative to where PowerShell is'
    }
    finally {
        Pop-Location
    }

    # Assert
    Assert-That -Condition (-not (Test-Path -LiteralPath $marker)) `
        -Message 'and nothing ran: the argument reached cmd.exe on no route'

    #───────────────────────────────────────────────────────────────────────────
    # Act - arguments with none of those characters in them
    $viaOperator = Invoke-NativeCapture -Command $batch -Arguments @('plain', 'two words')
    $viaProcess = Invoke-NativeCapture -Command $batch -Arguments @('plain', 'two words') -TimeoutSeconds 30

    # Assert
    Assert-Equal -Expected @('1=[plain] 2=[two words]') -Actual $viaOperator.Output `
        -Message 'An argument with none of those characters still reaches a batch file through the call operator'
    Assert-Equal -Expected @('1=[plain] 2=[two words]') -Actual $viaProcess.Output `
        -Message 'and through a process of its own'

    #───────────────────────────────────────────────────────────────────────────
    # Act - the same, for the .bat file
    $batViaOperator = Invoke-NativeCapture -Command $dotBat -Arguments @('plain', 'two words')
    $batViaProcess = Invoke-NativeCapture -Command $dotBat -Arguments @('plain', 'two words') -TimeoutSeconds 30

    # Assert
    Assert-Equal -Expected @('1=[plain] 2=[two words]') -Actual $batViaOperator.Output `
        -Message 'An argument with none of those characters reaches a .bat file through the call operator'
    Assert-Equal -Expected @('1=[plain] 2=[two words]') -Actual $batViaProcess.Output `
        -Message 'and through a process of its own'

    #───────────────────────────────────────────────────────────────────────────
    # Act - every one of those characters, for a command that is not a batch file
    $viaOperator = Invoke-NativeCapture -Command $pwsh `
        -Arguments @('-NoProfile', '-File', $echoArgs, 'say "hi" & a|b <c> ^d %e%')
    $viaProcess = Invoke-NativeCapture -Command $pwsh `
        -Arguments @('-NoProfile', '-File', $echoArgs, 'say "hi" & a|b <c> ^d %e%') `
        -TimeoutSeconds 30

    # Assert
    Assert-Equal -Expected @('[say "hi" & a|b <c> ^d %e%]') -Actual $viaOperator.Output `
        -Message 'A command that is not a batch file still gets them all through the call operator'
    Assert-Equal -Expected @('[say "hi" & a|b <c> ^d %e%]') -Actual $viaProcess.Output `
        -Message 'and through a process of its own'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an alias to the batch file, which the call operator follows
    Set-Alias -Name 'show-args-alias' -Value $batch -Scope Global
    $argument = "x&mkdir $marker"

    try {
        # Act / Assert
        Assert-Throws -ScriptBlock { Invoke-NativeCapture -Command 'show-args-alias' -Arguments @($argument) } `
            -MessageLike "Argument 1 for the batch file '$batch' holds one of*" `
            -Message 'A batch file reached through an alias is refused through the call operator'

        # Act
        $viaProcess = Invoke-NativeCapture -Command 'show-args-alias' -Arguments @($argument) -TimeoutSeconds 30
    }
    finally {
        Remove-Alias -Name 'show-args-alias' -Scope Global
    }

    # Assert
    Assert-That -Condition (-not $viaProcess.Started) -Message 'and a process of its own never runs an alias at all'
    Assert-That -Condition (-not (Test-Path -LiteralPath $marker)) `
        -Message 'so the argument reached cmd.exe on neither route'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the batch file found by name on PATH, and a function with that
    # name, which the call operator runs instead while a process of its own
    # still runs the batch file
    $originalPath = $env:PATH
    $env:PATH = $root + [Path]::PathSeparator + $env:PATH
    function global:show-args { "function got: $args" }
    try {
        # Act
        $result = Invoke-NativeCapture -Command 'show-args' -Arguments @('say "hi"')

        # Assert
        Assert-Equal -Expected @('function got: say "hi"') -Actual $result.Output `
            -Message 'What decides is the command that will really run, not its name'

        # Act / Assert
        Assert-Throws `
            -ScriptBlock { Invoke-NativeCapture -Command 'show-args' -Arguments @('say "hi"') -TimeoutSeconds 30 } `
            -MessageLike "Argument 1 for the batch file '$batch' holds one of*" `
            -Message 'so a process of its own, which runs the batch file the function hides, refuses the argument'
    }
    finally {
        Remove-Item -Path function:global:show-args
        $env:PATH = $originalPath
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a batch file in a folder named like a credential, which only
    # an @ after the drive's colon makes one
    $folder = Join-Path $root 'SENTINEL@h.example'
    New-Item -ItemType Directory -Path $folder | Out-Null
    $hiddenBatch = Join-Path $folder 'show-args.cmd'
    [File]::WriteAllText($hiddenBatch, "@echo off`r`n")

    $shown = [WildcardPattern]::Escape("Argument 1 for the batch file '***@h.example\show-args.cmd' holds one of")

    # Act / Assert
    Assert-Throws -ScriptBlock { Invoke-NativeCapture -Command $hiddenBatch -Arguments @('a&b') } `
        -MessageLike "$shown*" `
        -Message 'The batch file is named with the credential in its path hidden'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
