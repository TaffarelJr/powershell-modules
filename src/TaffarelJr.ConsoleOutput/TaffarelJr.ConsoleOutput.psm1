#Requires -Version 7.4
using namespace System.Collections.Generic

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Exported so a caller can align its own output to the same width without
# hard-coding it. ReadOnly, not Constant: a Constant can never be removed,
# so a second Import-Module -Force of this module would fail.
New-Variable -Name DefaultIndentWidth -Value 2 -Option ReadOnly -Scope Script

# The functions read this copy: a caller can still force a new value into the
# exported variable (Set-Variable -Force), and that must not reach them.
$script:IndentWidth = $DefaultIndentWidth

# Ambient state, per runspace: changed only through Push-Indent/Pop-Indent,
# Write-Step/Clear-Step, and Write-Doing/Write-Done.
$script:IndentStack = [Stack[int]]::new()
$script:LineOpen = $false
$script:OpenLineContinuation = ''
$script:StepNumber = 0
$script:CurrentStepLabel = ''

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Clear-Step'
    'Get-CurrentStep'
    'Get-Indent'
    'Invoke-Doing'
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
