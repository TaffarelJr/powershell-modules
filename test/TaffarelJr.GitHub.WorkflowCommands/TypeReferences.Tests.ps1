#Requires -Version 7.4
using namespace System.Management.Automation.Language

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a type literal for a class of the Utility or Management commands'
# assemblies fails in a new pwsh that has not loaded them yet, when that
# command's own use is what would have loaded them. FreshProcess.Tests.ps1 shows
# it in a real new pwsh, but only where startup leaves the assembly out; this
# finds the literal in the syntax tree, wherever the tests run.
$findReferences = {
    param([string]$Text)

    $tokens = $null
    $parseErrors = $null
    $tree = [Parser]::ParseInput($Text, [ref]$tokens, [ref]$parseErrors)
    $isTypeName = { param($node) $node -is [TypeExpressionAst] -or $node -is [TypeConstraintAst] }
    foreach ($node in $tree.FindAll($isTypeName, $true)) {
        if ($node.TypeName.FullName -like 'Microsoft.PowerShell.*') {
            $node.TypeName.FullName
        }
    }
}

# Act
$found = @(& $findReferences '$x -is [Microsoft.PowerShell.Commands.MatchInfo]')

# Assert
Assert-Equal -Expected @('Microsoft.PowerShell.Commands.MatchInfo') -Actual $found `
    -Message 'A type test against a Microsoft.PowerShell.Commands class is found'

#───────────────────────────────────────────────────────────────────────────────
# Act
$found = @(& $findReferences 'param([Microsoft.PowerShell.Commands.GenericMeasureInfo]$measure) $measure')

# Assert
Assert-Equal -Expected @('Microsoft.PowerShell.Commands.GenericMeasureInfo') -Actual $found `
    -Message 'A parameter typed with a Microsoft.PowerShell.Commands class is found'

#───────────────────────────────────────────────────────────────────────────────
# Act
$found = @(& $findReferences '$x -is [System.Management.Automation.ErrorRecord]; [string]$x')

# Assert
Assert-Equal -Expected @() -Actual $found `
    -Message 'Types of the core engine, which every pwsh has loaded, are not reported'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$sourceFiles = Get-ChildItem -LiteralPath (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands') `
    -Recurse -Filter *.ps1 -File

# Act
$named = foreach ($file in $sourceFiles) {
    foreach ($name in (& $findReferences (Get-Content -LiteralPath $file.FullName -Raw))) {
        "$($file.Name) names [$name]"
    }
}

# Assert
Assert-That -Condition ($sourceFiles.Count -gt 0) -Message 'The scan found the module''s source files'
Assert-Equal -Expected @() -Actual @($named) `
    -Message 'No source file names a Microsoft.PowerShell class, so none depends on an assembly that may not be loaded'

exit (Complete-TestRun)
