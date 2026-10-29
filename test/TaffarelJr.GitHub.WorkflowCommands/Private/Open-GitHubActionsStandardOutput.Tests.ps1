#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/Private/Open-GitHubActionsStandardOutput.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Act
$stream = Open-GitHubActionsStandardOutput
try {
    $writable = $stream.CanWrite
    $readable = $stream.CanRead
}
finally {
    $stream.Dispose()
}

# Assert
Assert-Equal -Expected $true -Actual $writable -Message 'The process''s standard output opens as a stream to write to'
Assert-Equal -Expected $false -Actual $readable -Message 'and only to write to'

exit (Complete-TestRun)
