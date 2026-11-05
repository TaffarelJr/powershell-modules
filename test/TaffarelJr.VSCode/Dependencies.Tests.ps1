#Requires -Version 7.4
using namespace System.Collections.Generic
using namespace System.IO

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars',
    '',
    Justification = 'The test defines a same-named command in the global scope, as another module or a script would.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# A module calls the commands of the modules it requires through its own scope,
# so a command of the same name that turns up in the global scope later - from
# another module, or a script - does not take its place.

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
$fileTextPath = Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1'
$vsCodePath = Join-Path $repoRoot 'src/TaffarelJr.VSCode/TaffarelJr.VSCode.psd1'
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module $fileTextPath -Force
Import-Module $vsCodePath -Force

$root = Join-Path ([Path]::GetTempPath()) "vscode-dependencies-$([Guid]::NewGuid())"
$repo = Join-Path $root 'repo'
New-Item -ItemType Directory -Path $repo | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a command the module really calls, defined in the global scope after the imports
    $global:ImpostorCalls = [List[string]]::new()
    function global:Write-TextFile {
        $global:ImpostorCalls.Add('Write-TextFile')
    }

    $workspace = Join-Path $root 'first.code-workspace'

    # Act
    $returned = New-VSCodeWorkspaceFile -Path $workspace -Folder $repo

    # Assert
    Assert-Equal -Expected @() -Actual @($global:ImpostorCalls) `
        -Message 'The workspace is written by the required module''s command, not one of the same name defined later'
    Assert-That -Condition ((Test-Path -LiteralPath $workspace) -and $returned -eq $workspace) `
        -Message 'so the file exists and its path is returned'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - both modules loaded again, the required one first, as a script that reloads them would
    Import-Module $fileTextPath -Force
    Import-Module $vsCodePath -Force
    $again = Join-Path $root 'second.code-workspace'

    # Act
    $null = New-VSCodeWorkspaceFile -Path $again -Folder $repo

    # Assert
    Assert-Equal -Expected @() -Actual @($global:ImpostorCalls) `
        -Message 'The same holds after the modules are imported again with -Force'
    Assert-That -Condition (Test-Path -LiteralPath $again) -Message 'and the file is written'

    Remove-Item -LiteralPath Function:\Write-TextFile

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the required module not loaded at all
    Remove-Module -Name 'TaffarelJr.FileText' -Force

    # Act / Assert - the module's root script says what is missing, rather than leave a call to fail later
    Assert-Throws -ScriptBlock {
        Import-Module (Join-Path $repoRoot 'src/TaffarelJr.VSCode/TaffarelJr.VSCode.psm1') -Force
    } -MessageLike '*TaffarelJr.FileText must be loaded before TaffarelJr.VSCode.*' `
        -Message 'A module imported without a module it requires says which one has to be loaded first'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
