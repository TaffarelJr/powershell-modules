#Requires -Version 7.4
using namespace System.IO
using namespace System.Management.Automation

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidOverwritingBuiltInCmdlets',
    '',
    Justification = 'One case stands in for the path lookup, inside one script block only.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    '',
    Justification = 'A test builds a fake secret from a literal.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') `
    -Force
$module = Get-Module TaffarelJr.ProcessInvocation
. (Join-Path $PSScriptRoot 'ProcessInvocationTestHelper.ps1')

function Get-CallOutcome {
    <#
    .SYNOPSIS
        Runs a script block and reports what it showed and how it ended.
    .DESCRIPTION
        Not exported - a test-only fixture. Collects the verbose lines as
        they are written, so those written before a failure are kept.
    .PARAMETER ScriptBlock
        The call to make.
    .OUTPUTS
        The error's message, target and rendered text (empty and $null when
        nothing failed), the verbose lines, and what was written to the
        pipeline.
    #>
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $raised = $null
    $seen = [System.Collections.Generic.List[object]]::new()
    try {
        & $ScriptBlock 4>&1 | ForEach-Object { $seen.Add($_) }
    }
    catch {
        $raised = $_
    }

    $verbose = @($seen | Where-Object { $_ -is [VerboseRecord] } | ForEach-Object { $_.Message })
    $output = @($seen | Where-Object { $_ -isnot [VerboseRecord] })
    return [PSCustomObject]@{
        Message  = if ($raised) { $raised.Exception.Message } else { '' }
        Target   = if ($raised) { $raised.TargetObject } else { $null }
        Rendered = if ($raised) { ($raised | Out-String) } else { '' }
        Verbose  = $verbose
        Output   = $output
    }
}

$secret = 'SENTINEL_SECRET_123'
$escape = { param([string]$Text) [WildcardPattern]::Escape($Text) }
Set-Item -Path function:global:Invoke-MaskProbe -Value {
    'token: SENTINEL_SECRET_123'
    'plain'
    $global:LASTEXITCODE = 7
}

$arguments = @('login', "--password=$secret", $secret, 'other')
$activity = "Signing in as $secret"
$shownCall = "Invoke-MaskProbe login '--password=***' '***' other"
$folder = Join-Path ([Path]::GetTempPath()) "mask-$([Guid]::NewGuid())-$secret"
$missing = Join-Path ([Path]::GetTempPath()) "missing-$([Guid]::NewGuid())-$secret"
New-Item -ItemType Directory -Path $folder | Out-Null

try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a failing call whose secret travels as an argument, with
    # and without -Mask
    $unmasked = Get-CallOutcome {
        Invoke-NativeCommand -Activity $activity -Command 'Invoke-MaskProbe' -Argument $arguments
    }
    $masked = Get-CallOutcome {
        Invoke-NativeCommand -Activity $activity -Command 'Invoke-MaskProbe' -Argument $arguments `
            -Mask $secret
    }

    # Assert
    Assert-That -Condition $unmasked.Message.Contains($secret) `
        -Message 'Without -Mask the secret is in the failure message'
    Assert-Equal -Expected "Signing in as *** failed: $shownCall (exit 7)`ntoken: ***`nplain" `
        -Actual $masked.Message `
        -Message 'With -Mask it is hidden in the activity, each word of the command line, and each line printed'
    Assert-Equal -Expected $masked.Message -Actual $masked.Target `
        -Message 'and so is the error''s target, which is that message'
    Assert-That -Condition (-not $masked.Rendered.Contains($secret)) `
        -Message 'and the error as PowerShell renders it'
    Assert-Equal -Expected @() -Actual $masked.Verbose `
        -Message 'Without -Verbose nothing is written to the verbose stream'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - the same call with -Verbose
    $verbose = Get-CallOutcome {
        Invoke-NativeCommand -Activity $activity -Command 'Invoke-MaskProbe' -Argument $arguments `
            -Mask $secret -Verbose
    }

    # Assert
    Assert-Equal -Expected @("Running: $shownCall") -Actual $verbose.Verbose `
        -Message 'The verbose line hides the secret'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - values that hide nothing
    $nullMask = Get-CallOutcome {
        Invoke-NativeCommand -Activity $activity -Command 'Invoke-MaskProbe' -Argument $arguments -Mask $null
    }
    $emptyMask = Get-CallOutcome {
        Invoke-NativeCommand -Activity $activity -Command 'Invoke-MaskProbe' -Argument $arguments -Mask @()
    }
    $shortMask = Get-CallOutcome {
        Invoke-NativeCommand -Activity $activity -Command 'Invoke-MaskProbe' -Argument $arguments `
            -Mask @('', 'abc')
    }

    # Assert
    Assert-Equal -Expected $unmasked.Message -Actual $nullMask.Message `
        -Message 'A $null -Mask leaves the message as it was'
    Assert-Equal -Expected $unmasked.Message -Actual $emptyMask.Message -Message 'and so does an empty one'
    Assert-Equal -Expected $unmasked.Message -Actual $shortMask.Message `
        -Message 'and one holding only an empty value and a value of fewer than four characters'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a program of its own that writes the secret to stdout and stderr
    $script = "[Console]::Out.WriteLine('out: $secret'); [Console]::Error.WriteLine('err: $secret'); exit 3"
    $shownScript = "'[Console]::Out.WriteLine(''out: ***''); " +
    "[Console]::Error.WriteLine(''err: ***''); exit 3'"
    $pattern = (& $escape 'Pushing as *** failed: ') + '*' +
    (& $escape " -NoProfile -Command $shownScript (exit 3)`nout: ***`nerr: ***")

    # Act
    $process = Get-CallOutcome {
        Invoke-NativeCommand -Activity "Pushing as $secret" -Command $pwsh -Argument @(
            '-NoProfile', '-Command', $script
        ) -SeparateStderr -TimeoutSeconds 60 -Mask $secret
    }

    # Assert
    Assert-That -Condition ($process.Message -like $pattern) `
        -Message 'A program on a process of its own has the secret hidden in its stdout and stderr lines'
    Assert-That -Condition (-not $process.Rendered.Contains($secret)) `
        -Message 'and in the error as PowerShell renders it'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a program that outlives its timeout
    $timedOut = Get-CallOutcome {
        Invoke-NativeCommand -Activity "Waiting as $secret" -Command $pwsh -Argument @(
            '-NoProfile', '-Command', "Write-Output '$secret'; Start-Sleep -Seconds 120"
        ) -TimeoutSeconds 2 -Mask $secret
    }

    # Assert
    Assert-That -Condition ($timedOut.Message -like '*(timed out after 2 seconds)*') `
        -Message 'A timeout is reported'
    Assert-That -Condition (-not $timedOut.Message.Contains($secret)) `
        -Message 'with the secret hidden in the message'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a command named after the secret that cannot be found, on each route
    $notFound = Get-CallOutcome {
        Invoke-NativeCommand -Activity $activity -Command "$secret-missing" -Mask $secret
    }
    $notFoundDirect = Get-CallOutcome {
        Invoke-NativeCommand -Activity $activity -Command "$secret-missing" -Mask $secret -TimeoutSeconds 30
    }

    # Assert
    $notFoundPattern = (& $escape ("Signing in as *** failed: could not run ***-missing " +
            "(The term '***-missing'")) + '*'
    Assert-That -Condition ($notFound.Message -like $notFoundPattern) `
        -Message 'A command that cannot be found is named hidden, in the message and in PowerShell''s reason'
    Assert-Equal -Expected ("Signing in as *** failed: could not run ***-missing" +
        " ('***-missing' is not an executable on PATH, and not the path to one.)") `
        -Actual $notFoundDirect.Message -Message 'and on a process of its own'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a working directory named after the secret that is not there
    $shownMissing = $missing.Replace($secret, '***')
    $noFolder = Get-CallOutcome {
        Invoke-NativeCommand -Activity $activity -Command $pwsh -WorkingDirectory $missing -Mask $secret
    }
    $read = Invoke-NativeRead -Command $pwsh -WorkingDirectory $missing -Mask $secret

    # Assert
    Assert-Equal `
        -Expected "Signing in as *** failed: could not run $pwsh (Working directory not found: $shownMissing)" `
        -Actual $noFolder.Message `
        -Message 'A working directory that is not there is named hidden'
    Assert-Equal -Expected @("Working directory not found: $missing") -Actual $read.Output `
        -Message 'while what a read returns is kept exactly as it is'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a read, with -Verbose
    $readOutcome = Get-CallOutcome {
        $result = Invoke-NativeRead -Command 'Invoke-MaskProbe' -Argument $arguments -Mask $secret -Verbose
        $result.Output
    }

    # Assert
    Assert-Equal -Expected @("Running: $shownCall") -Actual $readOutcome.Verbose `
        -Message 'A read hides the secret in its verbose line'
    Assert-Equal -Expected @('token: SENTINEL_SECRET_123', 'plain') -Actual $readOutcome.Output `
        -Message 'and returns what the command printed exactly as it was printed'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a verbose line that names a working directory holding the secret
    $inFolder = Get-CallOutcome {
        $null = Invoke-NativeRead -Command $pwsh -WorkingDirectory $folder -Mask $secret -Verbose `
            -Argument @('-NoProfile', '-Command', 'exit 0')
    }

    # Assert
    Assert-That -Condition ($inFolder.Verbose[0].EndsWith(" (in $($folder.Replace($secret, '***')))")) `
        -Message 'The line ends with the folder the command runs in, hidden'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a SecureString, which would be taken for its type name and hide nothing real
    $secure = ConvertTo-SecureString -String $secret -AsPlainText -Force

    # Act / Assert
    Assert-Throws `
        -ScriptBlock { Invoke-NativeCommand -Activity 'Signing in' -Command 'Invoke-MaskProbe' -Mask $secure } `
        -MessageLike '*-Mask takes plain text*SecureString*' `
        -Message 'Invoke-NativeCommand refuses a SecureString as -Mask, pointing at the plain text form'
    Assert-Throws -ScriptBlock { Invoke-NativeRead -Command 'Invoke-MaskProbe' -Mask @($secret, $secure) } `
        -MessageLike '*-Mask takes plain text*SecureString*' `
        -Message 'and so does Invoke-NativeRead, whether it is the only value or one of several'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a working directory on a provider other than the file system; no
    # such provider holds a folder named like the secret, so the path lookup
    # stands in for one
    $onProbe = "-WorkingDirectory 'C:\***' is on the Probe provider: give a folder on disk."

    # Act / Assert
    Assert-Throws `
        -ScriptBlock {
            & $module {
                param($value)
                function Test-Path { $true }
                function Resolve-Path { [PSCustomObject]@{ Provider = [PSCustomObject]@{ Name = 'Probe' } } }
                Invoke-NativeCapture -Command 'x' -WorkingDirectory 'C:\SENTINEL_SECRET_123' -Mask $value
            } $secret
        } `
        -MessageLike (& $escape $onProbe) `
        -Message 'A working directory on another provider is named hidden'
}
finally {
    Remove-Item -Path function:global:Invoke-MaskProbe
    Remove-Item -LiteralPath $folder -Recurse -Force
}

exit (Complete-TestRun)
