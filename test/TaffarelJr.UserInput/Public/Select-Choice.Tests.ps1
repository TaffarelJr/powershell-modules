#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Select-Choice's interactive path calls $Host.UI.PromptForChoice directly -
# a property of the automatic $Host variable, not a standalone command,
# so it cannot be shadowed the way Read-Host is
# in this module's other test files
# (confirmed: a global: function cannot override a module's own internal call,
# and $Host.UI isn't a command lookup at all).
# Calling the real thing here would block
# waiting for a keypress that will never come.
#
# Manual verification: Select-Choice -Prompt 'Pick one' -Option 'A',
# 'B' -Default 'B' shows a numbered menu with B pre-selected,
# and returns whichever label is chosen.

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - -Option is mandatory
try {
    Select-Choice -Prompt 'Pick one'
    Assert-That -Condition $false -Message '-Option is mandatory (did not throw)'
}
catch {
    Assert-That -Condition $true -Message '-Option is mandatory'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - -Prompt is mandatory
try {
    Select-Choice -Option 'A', 'B'
    Assert-That -Condition $false -Message '-Prompt is mandatory (did not throw)'
}
catch {
    Assert-That -Condition $true -Message '-Prompt is mandatory'
}

exit (Complete-TestRun)
