#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# One check across every function in the module: a function that is not
# advanced puts a misspelled parameter into $args without a word, so
# 'Reset-GitBranch -Mode Hard -RepoPth X' would reset the current folder's
# repository instead of X. The functions are found by reflection, so a
# function added later that forgets [CmdletBinding()] fails here.

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$manifestPath = Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1'
$module = Import-Module $manifestPath -Force -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
$publicFolder = Join-Path $repoRoot 'src/TaffarelJr.Git/Public'
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
# Arrange
$privateFolder = Join-Path $repoRoot 'src/TaffarelJr.Git/Private'
$privateNames = @((Get-ChildItem -LiteralPath $privateFolder -Filter *.ps1).BaseName | Sort-Object)

# Act
$simplePrivate = @(& $module {
        param($Names)
        Get-Command -Name $Names -CommandType Function | Where-Object { -not $_.CmdletBinding } | ForEach-Object Name
    } $privateNames)

# Assert
Assert-That -Condition ($privateNames -contains 'Invoke-GitCommand') `
    -Message 'Precondition: the private functions were found'
Assert-Equal -Expected @() -Actual $simplePrivate -Message 'and every private function is an advanced function too'

#───────────────────────────────────────────────────────────────────────────────
# Act
$misspelled = { Get-GitStatus -RepoPth 'C:\no\such\folder' }

# Assert
Assert-Throws -ScriptBlock $misspelled -MessageLike "*parameter cannot be found*'RepoPth'*" `
    -Message 'A misspelled parameter is refused rather than ignored'

#───────────────────────────────────────────────────────────────────────────────
# Act
$unhelped = @($exported.Where({ (Get-Help $_).Synopsis -cnotmatch '^[A-Z][a-z]+s ' }))

# Assert
Assert-Equal -Expected @() -Actual $unhelped `
    -Message 'Every exported function has comment-based help with a third-person synopsis'

exit (Complete-TestRun)
