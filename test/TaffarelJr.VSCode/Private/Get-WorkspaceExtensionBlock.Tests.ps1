#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/ConvertTo-JsonLiteral.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Get-WorkspaceExtensionBlock.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Act
$omitted = Get-WorkspaceExtensionBlock
$empty = Get-WorkspaceExtensionBlock -Extension @()

# Assert
Assert-That -Condition ($omitted -is [array]) -Message 'No extensions still returns an array'
Assert-Equal -Expected 0 -Actual $omitted.Count -Message 'An omitted -Extension writes nothing'
Assert-Equal -Expected 0 -Actual $empty.Count -Message 'An empty -Extension writes nothing'

#───────────────────────────────────────────────────────────────────────────────
# Act
$lines = Get-WorkspaceExtensionBlock -Extension 'ms-vscode.powershell'

# Assert
$expected = @(
    '  "extensions": {'
    '    "recommendations": ['
    '      "ms-vscode.powershell"'
    '    ]'
    '  }'
)
Assert-Equal -Expected $expected -Actual $lines -Message 'One extension is one line, with no trailing comma'

#───────────────────────────────────────────────────────────────────────────────
# Act
$lines = Get-WorkspaceExtensionBlock -Extension 'a.one', 'b.two', 'c.three'

# Assert
Assert-Equal -Expected @('      "a.one",', '      "b.two",', '      "c.three"') -Actual $lines[2..4] -Message 'A comma follows every extension but the last, in the order given'

exit (Complete-TestRun)
