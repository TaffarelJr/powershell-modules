#Requires -Version 7.0
using namespace System.Collections.Generic

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Public, read-only: the width every Push-Indent/Invoke-Indented defaults to,
# and what Format-LineIndent adds on top of the ambient indent.
# Exported so a caller can align its own output
# to the same width without hard-coding it.
# ReadOnly, not Constant - a Constant can never be removed
# for the life of the process, which breaks
# a second Import-Module -Force of this module within the same session,
# however that second import comes to happen.
New-Variable -Name DefaultIndentWidth -Value 2 -Option ReadOnly -Scope Script

# Ambient state. Read/written only by this module's own functions -
# a caller never touches these directly,
# which is the entire point of Push-Indent/Pop-Indent
# and Write-Step/Clear-Step existing.
$script:IndentStack = [Stack[int]]::new()
$script:LineOpen = $false
$script:StepNumber = 0
$script:CurrentStepLabel = ''

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Clear-Step'
    'Get-CurrentStep'
    'Get-Indent'
    'Invoke-Indented'
    'Pop-Indent'
    'Push-Indent'
    'Write-Banner'
    'Write-Detail'
    'Write-Doing'
    'Write-Done'
    'Write-Failure'
    'Write-Field'
    'Write-Header'
    'Write-Info'
    'Write-Skip'
    'Write-Step'
    'Write-Success'
    'Write-Warn'
)

Export-ModuleMember -Variable 'DefaultIndentWidth'
