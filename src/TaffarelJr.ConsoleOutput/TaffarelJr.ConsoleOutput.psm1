#Requires -Version 7.6
using namespace System.Collections.Generic

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Exported so a caller can align its own output to the same width without
# hard-coding it. ReadOnly, not Constant: an exported Constant can never be
# removed, so a second Import-Module -Force of this module would fail.
New-Variable -Name DefaultIndentWidth -Value 2 -Option ReadOnly -Scope Script

# The functions read this copy: a caller can still force a new value into the
# exported variable (Set-Variable -Force), and that must not reach them.
$script:IndentWidth = $DefaultIndentWidth

New-Variable -Name FallbackConsoleWidth -Value 80 -Option Constant -Scope Script

$script:IndentStack = [Stack[int]]::new()
$script:IndentSize = 0

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Get-Indent'
    'Get-IndentSize'
    'Invoke-Indented'
    'Pop-Indent'
    'Push-Indent'
    'Reset-Indent'
    'Show-Banner'
    'Show-Detail'
    'Show-Failure'
    'Show-Header'
    'Show-Info'
    'Show-Skip'
    'Show-Success'
    'Show-Warning'
)

Export-ModuleMember -Variable 'DefaultIndentWidth'
