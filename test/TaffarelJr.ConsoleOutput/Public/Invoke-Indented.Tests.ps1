#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force

# Arrange
$script:capturedIndent = -1

# Act
Invoke-Indented -Width 5 -ScriptBlock { $script:capturedIndent = Get-Indent }

# Assert
Assert-Equal -Expected 5 -Actual $script:capturedIndent -Message 'The script block runs with the indent pushed'
Assert-Equal -Expected 0 -Actual (Get-Indent) -Message 'The indent is popped after the script block returns'

# Arrange / Act - default width
Invoke-Indented -ScriptBlock { $script:capturedIndent = Get-Indent }

# Assert
Assert-Equal -Expected 2 -Actual $script:capturedIndent -Message 'Invoke-Indented defaults to a width of 2'
Assert-Equal -Expected 0 -Actual (Get-Indent) -Message 'The indent is popped after the default-width block too'

# Act - the block throws
try {
    Invoke-Indented -ScriptBlock { throw 'boom' }
}
catch {
    # expected - Invoke-Indented does not swallow the caller's exception
}

# Assert
Assert-Equal -Expected 0 -Actual (Get-Indent) -Message 'The indent is popped even when the script block throws'

exit (Complete-TestRun)
