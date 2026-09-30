#Requires -Version 7.0
using namespace System.Collections.Generic

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Public, read-only: the width every Push-Indent/Invoke-Indented defaults to,
# and what Get-LineIndent adds on top of the ambient indent.
# Exported so a caller can align its own output
# to the same width without hard-coding it.
New-Variable -Name DefaultIndentWidth -Value 2 -Option Constant -Scope Script

# Ambient state. Read/written only by this module's own functions -
# a caller never touches these directly, which is the entire point
# of Push-Indent/Pop-Indent and Write-Step/Clear-Step existing.
$script:IndentStack = [Stack[int]]::new()
$script:LineOpen = $false
$script:StepNumber = 0
$script:CurrentStepLabel = ''

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Push-Indent'
    'Pop-Indent'
    'Get-Indent'
    'Invoke-Indented'
    'Get-CurrentStep'
    'Write-Success'
    'Write-Skip'
    'Write-Warn'
    'Write-Failure'
    'Write-Info'
    'Write-Detail'
    'Write-Field'
    'Write-Doing'
    'Write-Done'
    'Write-Step'
    'Clear-Step'
    'Write-Header'
    'Write-Banner'
)

Export-ModuleMember -Variable 'DefaultIndentWidth'
