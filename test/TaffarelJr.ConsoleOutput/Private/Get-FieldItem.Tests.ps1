#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
$module = Get-Module TaffarelJr.ConsoleOutput

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$flat = @(& $module { Get-FieldItem -Value @(1, @(2, @(3, 4)), 'five') })

# Assert
Assert-Equal -Expected @('1', '2', '3', '4', 'five') -Actual $flat -Message 'Lists inside the list are flattened, at any depth'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$withDictionary = @(& $module { Get-FieldItem -Value @('a', @{ k = 'v' }) })
$empty = @(& $module { Get-FieldItem -Value @() })

# Assert
Assert-Equal -Expected @('a', '{k = v}') -Actual $withDictionary `
    -Message 'A dictionary inside the list is one item, printed inline, not a list to flatten'
Assert-Equal -Expected 0 -Actual $empty.Count -Message 'An empty list gives nothing'

exit (Complete-TestRun)
