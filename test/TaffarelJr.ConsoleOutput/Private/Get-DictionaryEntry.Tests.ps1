#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ConsoleOutputTestHelper.ps1')
$module = Get-Module TaffarelJr.ConsoleOutput
#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$entries = @(& $module { Get-DictionaryEntry -Value ([ordered]@{ b = @(1, 2); 2 = 'two'; a = @{ k = 'v' } }) })
$none = @(& $module { Get-DictionaryEntry -Value @{} })

# Assert
Assert-Equal -Expected @('2 = two', 'a = {k = v}', 'b = 1, 2') -Actual $entries `
    -Message 'One "key = value" entry each, sorted by the key''s text, a list and a dictionary inline'
Assert-Equal -Expected 0 -Actual $none.Count -Message 'An empty dictionary gives nothing'

exit (Complete-TestRun)
