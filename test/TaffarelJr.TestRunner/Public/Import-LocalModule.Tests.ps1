#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/TaffarelJr.TestRunner.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'TestRunnerTestHelper.ps1')

function New-ModuleFolder {
    <#
    .SYNOPSIS
        Makes a folder with the given name inside a sandbox, holding the given
        files: a module file is a function named Get-<Name>Marker, a manifest
        names the .psm1 of the same name, and anything else is plain text.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Sandbox,

        [Parameter(Mandatory)]
        [string]$Folder,

        [Parameter(Mandatory)]
        [hashtable]$File
    )

    $path = Join-Path $Sandbox $Folder
    New-Item -ItemType Directory -Path $path | Out-Null
    foreach ($name in $File.Keys) {
        Set-Content -LiteralPath (Join-Path $path $name) -Value $File[$name]
    }

    return $path
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a folder with both a manifest and its own sibling .psm1
$sandbox = New-TestRunnerSandbox
$manifestModuleFolder = New-ModuleFolder -Sandbox $sandbox -Folder 'ModuleWithManifest' -File @{
    'ModuleWithManifest.psm1' = "function Get-ManifestModuleMarker { 'manifest' }`nExport-ModuleMember -Function Get-ManifestModuleMarker"
    'ModuleWithManifest.psd1' = "@{ RootModule = 'ModuleWithManifest.psm1'; ModuleVersion = '1.0.0' }"
}

# Act
Import-LocalModule -Path $manifestModuleFolder

# Assert
Assert-Equal -Expected 'manifest' -Actual (Get-ManifestModuleMarker) `
    -Message 'A manifest-rooted folder is imported by its .psd1'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a folder with only a bare .psm1, no manifest at all, plus a loose
# .ps1 alongside it that must never be touched
$bareModuleFolder = New-ModuleFolder -Sandbox $sandbox -Folder 'BareModuleHelpers' -File @{
    'BareModuleHelpers.psm1' = "function Get-BareModuleMarker { 'bare' }`nExport-ModuleMember -Function Get-BareModuleMarker"
    'Invoke-Something.ps1'   = "throw 'Invoke-Something was executed - Import-LocalModule must never touch a bare .ps1'"
}

# Act
Import-LocalModule -Path $bareModuleFolder

# Assert
Assert-Equal -Expected 'bare' -Actual (Get-BareModuleMarker) `
    -Message 'A folder with no manifest is imported by its bare .psm1'
Assert-That -Condition (-not (Get-Command -Name 'Invoke-Something' -ErrorAction SilentlyContinue)) `
    -Message 'A loose .ps1 alongside the module defines no command at all - it was never dot-sourced'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a folder with neither a .psd1 nor a .psm1 throws,
# rather than silently doing nothing
$emptyFolder = New-ModuleFolder -Sandbox $sandbox -Folder 'Empty' -File @{ 'notes.txt' = 'nothing here' }

# Assert
Assert-Throws -ScriptBlock {
    Import-LocalModule -Path $emptyFolder
} -Message 'An empty folder throws, naming the path' -MessageLike "*$emptyFolder*"

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a data file that sorts before the real manifest, in a folder named
# after the module
$dataFirstFolder = New-ModuleFolder -Sandbox $sandbox -Folder 'Zeta' -File @{
    'Alpha.psd1' = "@{ Rules = @('A', 'B') }"
    'Zeta.psm1'  = "function Get-ZetaMarker { 'zeta' }`nExport-ModuleMember -Function Get-ZetaMarker"
    'Zeta.psd1'  = "@{ RootModule = 'Zeta.psm1'; ModuleVersion = '1.0.0'; FunctionsToExport = @('Get-ZetaMarker') }"
}

# Act
Import-LocalModule -Path $dataFirstFolder

# Assert
Assert-Equal -Expected 'zeta' -Actual (Get-ZetaMarker) `
    -Message 'With several .psd1 files, the one named like the folder is the module, not whichever sorts first'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same, reached through a path that ends in a separator
$trailingFolder = New-ModuleFolder -Sandbox $sandbox -Folder 'Omega' -File @{
    'Aardvark.psd1' = "@{ Rules = @('A') }"
    'Omega.psm1'    = "function Get-OmegaMarker { 'omega' }`nExport-ModuleMember -Function Get-OmegaMarker"
    'Omega.psd1'    = "@{ RootModule = 'Omega.psm1'; ModuleVersion = '1.0.0'; FunctionsToExport = @('Get-OmegaMarker') }"
}

# Act
Import-LocalModule -Path ($trailingFolder + [System.IO.Path]::DirectorySeparatorChar)

# Assert
Assert-Equal -Expected 'omega' -Actual (Get-OmegaMarker) `
    -Message 'A trailing separator on the path does not hide the folder''s name'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - several .psd1 files and none named like the folder
$ambiguousFolder = New-ModuleFolder -Sandbox $sandbox -Folder 'Ambiguous' -File @{
    'One.psd1' = "@{ ModuleVersion = '1.0.0' }"
    'Two.psd1' = "@{ ModuleVersion = '1.0.0' }"
}

# Assert
Assert-Throws -ScriptBlock {
    Import-LocalModule -Path $ambiguousFolder
} -MessageLike "*More than one module file*'Ambiguous'*One.psd1, Two.psd1*" `
    -Message 'Several manifests and none named like the folder throws, naming them instead of picking one'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - several bare .psm1 files and none named like the folder
$twoBareFolder = New-ModuleFolder -Sandbox $sandbox -Folder 'TwoBare' -File @{
    'First.psm1'  = 'function Get-FirstMarker { 1 }'
    'Second.psm1' = 'function Get-SecondMarker { 2 }'
}

# Assert
Assert-Throws -ScriptBlock {
    Import-LocalModule -Path $twoBareFolder
} -MessageLike '*More than one module file*First.psm1, Second.psm1*' `
    -Message 'Several bare .psm1 files and none named like the folder throws too'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - several bare .psm1 files, one named like the folder
$namedBareFolder = New-ModuleFolder -Sandbox $sandbox -Folder 'Chosen' -File @{
    'Aaa.psm1'    = 'function Get-AaaMarker { 1 }'
    'Chosen.psm1' = "function Get-ChosenMarker { 'chosen' }"
}

# Act
Import-LocalModule -Path $namedBareFolder

# Assert
Assert-Equal -Expected 'chosen' -Actual (Get-ChosenMarker) `
    -Message 'With several bare .psm1 files, the one named like the folder is imported'
Assert-That -Condition (-not (Get-Command -Name 'Get-AaaMarker' -ErrorAction SilentlyContinue)) `
    -Message 'and the others are left alone'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a lone .psd1 that is not a module manifest at all
$dataOnlyFolder = New-ModuleFolder -Sandbox $sandbox -Folder 'DataOnly' `
    -File @{ 'DataOnly.psd1' = "@{ Rules = @('A') }" }

# Assert
Assert-Throws -ScriptBlock {
    Import-LocalModule -Path $dataOnlyFolder
} -MessageLike '*DataOnly.psd1*not valid*' `
    -Message 'A data file that is not a manifest fails at the import, naming the file'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a folder that merely has the name of a manifest
$folderNamedLikeFile = New-ModuleFolder -Sandbox $sandbox -Folder 'Decoy' `
    -File @{ 'Decoy.psm1' = "function Get-DecoyMarker { 'decoy' }" }
New-Item -ItemType Directory -Path (Join-Path $folderNamedLikeFile 'Decoy.psd1') | Out-Null

# Act
Import-LocalModule -Path $folderNamedLikeFile

# Assert
Assert-Equal -Expected 'decoy' -Actual (Get-DecoyMarker) `
    -Message 'A subfolder named like a manifest is not mistaken for one'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module with no manifest, beside a settings file that is the only
# .psd1 in the folder
$settingsFolder = New-ModuleFolder -Sandbox $sandbox -Folder 'Settled' -File @{
    'Settled.psm1'                  = "function Get-SettledMarker { 'settled' }"
    'PSScriptAnalyzerSettings.psd1' = "@{ Severity = @('Error', 'Warning') }"
}

# Act
Import-LocalModule -Path $settingsFolder

# Assert
Assert-Equal -Expected 'settled' -Actual (Get-SettledMarker) `
    -Message 'A .psm1 named like the folder wins over a lone .psd1 named otherwise'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one manifest and one .psm1, neither named like the folder
$loneFolder = New-ModuleFolder -Sandbox $sandbox -Folder 'Lone' -File @{
    'Inner.psm1'    = "function Get-InnerMarker { 'inner' }"
    'Manifest.psd1' = "@{ RootModule = 'Inner.psm1'; ModuleVersion = '1.0.0'; FunctionsToExport = @('Get-InnerMarker') }"
}

# Act
Import-LocalModule -Path $loneFolder

# Assert
Assert-Equal -Expected 'inner' -Actual (Get-InnerMarker) `
    -Message 'With nothing named like the folder, a lone .psd1 is the module'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a single .psm1, not named like the folder, and no manifest
$looseFolder = New-ModuleFolder -Sandbox $sandbox -Folder 'Loose' -File @{
    'Different.psm1' = "function Get-DifferentMarker { 'different' }"
}

# Act
Import-LocalModule -Path $looseFolder

# Assert
Assert-Equal -Expected 'different' -Actual (Get-DifferentMarker) `
    -Message 'With no manifest and nothing named like the folder, a lone .psm1 is the module'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - two manifests and one .psm1, none named like the folder
$twoManifestsFolder = New-ModuleFolder -Sandbox $sandbox -Folder 'TwoManifests' -File @{
    'One.psd1'   = "@{ ModuleVersion = '1.0.0' }"
    'Two.psd1'   = "@{ ModuleVersion = '1.0.0' }"
    'Three.psm1' = "function Get-ThreeMarker { 3 }"
}

# Assert
Assert-Throws -ScriptBlock {
    Import-LocalModule -Path $twoManifestsFolder
} -MessageLike '*More than one module file*One.psd1, Two.psd1, Three.psm1*' `
    -Message 'Two manifests and a .psm1, none named like the folder, throw, rather than take the lone .psm1'
Assert-That -Condition (-not (Get-Command -Name 'Get-ThreeMarker' -ErrorAction SilentlyContinue)) `
    -Message 'and the .psm1 is left alone'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one manifest and two .psm1 files, none named like the folder
$manifestAndTwoFolder = New-ModuleFolder -Sandbox $sandbox -Folder 'ManifestAndTwo' -File @{
    'Core.psm1'     = "function Get-CoreMarker { 'core' }"
    'Extra.psm1'    = "function Get-ExtraMarker { 'extra' }"
    'Settings.psd1' = "@{ RootModule = 'Core.psm1'; ModuleVersion = '1.0.0'; FunctionsToExport = @('Get-CoreMarker') }"
}

# Act
Import-LocalModule -Path $manifestAndTwoFolder

# Assert
Assert-Equal -Expected 'core' -Actual (Get-CoreMarker) `
    -Message 'One manifest and two .psm1 files, none named like the folder, import the manifest'
Assert-That -Condition (-not (Get-Command -Name 'Get-ExtraMarker' -ErrorAction SilentlyContinue)) `
    -Message 'and the .psm1 files it does not name are left alone'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a module file instead of its folder, and a folder
# that does not exist
$moduleFile = Join-Path $bareModuleFolder 'BareModuleHelpers.psm1'

# Assert
Assert-Throws -ScriptBlock {
    Import-LocalModule -Path $moduleFile
} -MessageLike "Not a module folder: $moduleFile*" `
    -Message 'A file path is refused, since the folder is what is asked for'

# Act
$noFolder = Join-Path $sandbox 'NoSuchModule'

# Assert
Assert-Throws -ScriptBlock {
    Import-LocalModule -Path $noFolder
} -MessageLike "Not a module folder: $noFolder*" -Message 'A folder that does not exist is refused, naming it'

# Cleanup

# Act
$imported = 'ModuleWithManifest', 'BareModuleHelpers', 'Zeta', 'Omega', 'Chosen',
    'Decoy', 'Settled', 'Manifest', 'Different', 'Settings'
Remove-Module -Name $imported -Force -ErrorAction SilentlyContinue
Remove-TestRunnerSandbox -Path $sandbox

exit (Complete-TestRun)
