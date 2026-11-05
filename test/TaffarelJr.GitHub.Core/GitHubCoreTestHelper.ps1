using namespace System.IO

# Shared by TaffarelJr.GitHub.Core's own test files; the fake gh and the fake
# server every GitHub module uses are in ../GitHubTestHelper.ps1.
function New-CoreTestFolder {
    <#
    .SYNOPSIS
        Creates an empty scratch folder with two empty subfolders, here and
        there, for a test that splits PowerShell's location from the
        process's.
    .DESCRIPTION
        Not exported - a test-only fixture.
    .OUTPUTS
        The scratch folder's full path. Remove it with Remove-CoreTestFolder.
    #>
    [CmdletBinding()]
    param()

    $root = Join-Path ([Path]::GetTempPath()) "gh-core-test-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path (Join-Path $root 'here') | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root 'there') | Out-Null
    return $root
}

function Remove-CoreTestFolder {
    <#
    .SYNOPSIS
        Deletes a scratch folder New-CoreTestFolder made.
    .DESCRIPTION
        Not exported - a test-only fixture. Tolerates a folder that is
        already gone.
    .PARAMETER Path
        The scratch folder.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

$callerManifests = foreach ($name in 'TaffarelJr.ProcessInvocation', 'TaffarelJr.GitHub.Core') {
    Join-Path $PSScriptRoot '..' '..' 'src' $name "$name.psd1"
}

function Invoke-CallerScript {
    <#
    .SYNOPSIS
        Runs a script as an ordinary caller's script runs, in a new runspace,
        and returns what it wrote and the errors it reported.
    .DESCRIPTION
        Not exported - a test-only fixture. A statement that fails with a
        terminating error ends there, the error is reported, and the script
        carries on at its next line. Inside a test's own try block the same
        failure would be thrown to that block instead, so a test of what a
        caller sees under -ErrorAction SilentlyContinue or Ignore runs the
        call here, with no try around it.

        The runspace imports this module and the module it requires by
        path, and shares this process's environment, so a fake gh put on
        PATH answers in it too.
    .PARAMETER Script
        The code to run.
    .OUTPUTS
        An object - Output (what the script wrote) and Error (the error
        records it reported, as the runspace's error stream holds them).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Script
    )

    $shell = [powershell]::Create()
    try {
        foreach ($manifest in $callerManifests) {
            $import = $shell.AddCommand('Import-Module').AddParameter('Name', $manifest)
            $null = $import.AddParameter('Force').AddStatement()
        }

        $null = $shell.AddScript($Script)
        $output = $shell.Invoke()
        return [PSCustomObject]@{
            Output = @($output)
            Error  = @($shell.Streams.Error)
        }
    }
    finally {
        $shell.Dispose()
    }
}

function Get-GitHubCallOutcome {
    <#
    .SYNOPSIS
        Runs a script block and reports everything a secret could leak
        through: what it said, and how it failed.
    .DESCRIPTION
        Not exported - a test-only fixture. Collects the verbose lines as
        they are written, so those written before a failure are kept, and
        clears $Error first so $Error[0] is this call's own failure.
    .PARAMETER ScriptBlock
        The call to make.
    .OUTPUTS
        An object - Message, Target and the text PowerShell renders for the
        error (Rendered), what Get-Error shows for the error it was thrown as
        (Detail) and for $Error[0] (Last); all empty when nothing failed. Also
        Verbose, each verbose line, and Output, what was written to the
        pipeline.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $raised = $null
    $seen = [System.Collections.Generic.List[object]]::new()
    $global:Error.Clear()
    try {
        & $ScriptBlock 4>&1 | ForEach-Object { $seen.Add($_) }
    }
    catch {
        $raised = $_
    }

    $record = [System.Management.Automation.VerboseRecord]
    $verbose = @($seen | Where-Object { $_ -is $record } | ForEach-Object { $_.Message })
    $output = @($seen | Where-Object { $_ -isnot $record })
    return [PSCustomObject]@{
        Message  = if ($raised) { $raised.Exception.Message } else { '' }
        Target   = if ($raised) { $raised.TargetObject } else { $null }
        Rendered = if ($raised) { ($raised | Out-String) } else { '' }
        Detail   = if ($raised) { ($raised | Get-Error | Out-String) } else { '' }
        Last     = if ($raised) { (Get-Error | Out-String) } else { '' }
        Verbose  = $verbose
        Output   = $output
    }
}

function Get-LeakingSurface {
    <#
    .SYNOPSIS
        Names each place a text shows up in what Get-GitHubCallOutcome
        reported.
    .DESCRIPTION
        Not exported - a test-only fixture. An empty answer means the text
        is in none of the message, the error's target, the way PowerShell
        renders the error, what Get-Error shows, and the verbose lines.
    .PARAMETER Outcome
        What Get-GitHubCallOutcome returned.
    .PARAMETER Text
        The text that must appear nowhere.
    .OUTPUTS
        The name of each surface that holds the text, one at a time.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Outcome,

        [Parameter(Mandatory)]
        [string]$Text
    )

    $surfaces = [ordered]@{
        Message  = $Outcome.Message
        Target   = "$($Outcome.Target)"
        Rendered = $Outcome.Rendered
        Detail   = $Outcome.Detail
        Last     = $Outcome.Last
        Verbose  = $Outcome.Verbose -join "`n"
    }

    foreach ($name in $surfaces.Keys) {
        if ($surfaces[$name].Contains($Text)) {
            $name
        }
    }
}
