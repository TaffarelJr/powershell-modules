# Shared by TaffarelJr.GitHub.Search's own test files; the fake gh and the fake
# server every GitHub module uses are in ../GitHubTestHelper.ps1.
$searchModules = 'TaffarelJr.ProcessInvocation', 'TaffarelJr.GitHub.Core', 'TaffarelJr.GitHub.Search'
$searchManifests = foreach ($name in $searchModules) {
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

        The runspace imports this module and the modules it needs by path,
        and shares this process's environment, so a fake gh put on PATH
        answers in it too.
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
        foreach ($manifest in $searchManifests) {
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
