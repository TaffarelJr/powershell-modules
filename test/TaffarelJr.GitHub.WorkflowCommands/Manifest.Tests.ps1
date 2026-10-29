#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$manifestPath = Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1'
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module $manifestPath -Force
$module = Get-Module TaffarelJr.GitHub.WorkflowCommands

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
$publicFolder = Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/Public'
$publicFiles = @((Get-ChildItem -LiteralPath $publicFolder -Filter *.ps1).BaseName | Sort-Object)

# Act
$exported = @($module.ExportedFunctions.Keys | Sort-Object)

# Assert
Assert-Equal -Expected $publicFiles -Actual $exported -Message 'The module exports exactly one function per Public file'
Assert-Equal -Expected $publicFiles -Actual @($manifest.FunctionsToExport | Sort-Object) `
    -Message 'and the manifest lists exactly those'

#───────────────────────────────────────────────────────────────────────────────
# Act
$simple = @($module.ExportedFunctions.Values | Where-Object { -not $_.CmdletBinding } | ForEach-Object Name)

# Assert
Assert-Equal -Expected @() -Actual $simple `
    -Message 'Every exported function is an advanced function, so a stray or misspelled argument throws'

#───────────────────────────────────────────────────────────────────────────────
# Act
$unhelped = @($exported.Where({ (Get-Help $_).Synopsis -cnotmatch '^[A-Z][a-z]+s ' }))

# Assert
Assert-Equal -Expected @() -Actual $unhelped `
    -Message 'Every exported function has comment-based help with a third-person synopsis'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the assemblies every pwsh has loaded before its first command: the
# runtime's own, PowerShell's, the console's, and each that holds a type
# accelerator, as PowerShell loads those to resolve any type name
$accelerators = [psobject].Assembly.GetType('System.Management.Automation.TypeAccelerators')::Get
$loaded = [System.Collections.Generic.HashSet[string]]::new()
foreach ($name in 'System.Private.CoreLib', 'System.Management.Automation', 'System.Console') {
    $null = $loaded.Add($name)
}

foreach ($type in $accelerators.PSBase.Values) {
    $null = $loaded.Add($type.Assembly.GetName().Name)
}

$sources = Get-ChildItem -LiteralPath (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands') -Recurse `
    -Include *.ps1, *.psm1

# Act
$late = foreach ($source in $sources) {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($source.FullName, [ref]$null, [ref]$null)
    $typeNames = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.TypeExpressionAst] -or
            $node -is [System.Management.Automation.Language.TypeConstraintAst]
        }, $true)
    foreach ($typeName in $typeNames) {
        $type = $typeName.TypeName.GetReflectionType()
        if ($null -eq $type -or -not $loaded.Contains($type.Assembly.GetName().Name)) {
            "$($source.Name):$($typeName.Extent.StartLineNumber) [$($typeName.TypeName.FullName)]"
        }
    }
}

# Assert
Assert-Equal -Expected @() -Actual @($late) `
    -Message 'The source names no type from an assembly a new pwsh may not have loaded yet, as that type literal would throw there'

exit (Complete-TestRun)
