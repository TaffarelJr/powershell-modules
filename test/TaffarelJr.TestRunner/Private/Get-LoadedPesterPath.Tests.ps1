#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# What Pester this session has loaded depends on how the file is run (the
# coverage wrapper loads one), so every case decides it with a stand-in.

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/TaffarelJr.TestRunner.psd1') -Force -PassThru
. (Join-Path $PSScriptRoot '..' 'TestRunnerTestHelper.ps1')

function New-LoadedModule {
    <#
    .SYNOPSIS
        Returns what Get-Module would say about a loaded module.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [string]$ModuleBase
    )

    return [PSCustomObject]@{
        Name       = 'Pester'
        Version    = [version]$Version
        ModuleBase = $ModuleBase
        Path       = Join-Path $ModuleBase 'Pester.psm1'
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - three loaded Pesters, the newest one of them with a manifest
$sandbox = New-TestRunnerSandbox
$newest = Split-Path -Parent (New-FakePester -Directory (Join-Path $sandbox 'newest') -Version '5.7.0')
$older = Split-Path -Parent (New-FakePester -Directory (Join-Path $sandbox 'older') -Version '5.5.0')
$script:loaded = @(
    New-LoadedModule -Version '5.5.0' -ModuleBase $older
    New-LoadedModule -Version '5.7.0' -ModuleBase $newest
    New-LoadedModule -Version '5.2.0' -ModuleBase $older
)

# Act
$path = Invoke-WithSeam -Module $module -Name 'Get-Module' -Replacement { $script:loaded } -ScriptBlock {
    & $module { Get-LoadedPesterPath }
}

# Assert
Assert-Equal -Expected (Join-Path $newest 'Pester.psd1') -Actual $path `
    -Message 'The newest loaded Pester is chosen, by its manifest'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a loaded Pester whose folder has no manifest
$bare = New-Item -ItemType Directory -Path (Join-Path $sandbox 'bare')
$script:loaded = @(New-LoadedModule -Version '5.6.0' -ModuleBase $bare.FullName)

# Act
$barePath = Invoke-WithSeam -Module $module -Name 'Get-Module' -Replacement { $script:loaded } -ScriptBlock {
    & $module { Get-LoadedPesterPath }
}

# Assert
Assert-Equal -Expected (Join-Path $bare.FullName 'Pester.psm1') -Actual $barePath `
    -Message 'Without a manifest, the path it was loaded from is used'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - only a Pester too old to run the wrapper
$script:loaded = @(New-LoadedModule -Version '5.2.0' -ModuleBase $older)

# Act
$tooOld = Invoke-WithSeam -Module $module -Name 'Get-Module' -Replacement { $script:loaded } -ScriptBlock {
    & $module { Get-LoadedPesterPath }
}
$nothing = Invoke-WithSeam -Module $module -Name 'Get-Module' -Replacement { } -ScriptBlock {
    & $module { Get-LoadedPesterPath }
}

# Assert
Assert-Equal -Expected $null -Actual $tooOld -Message 'A Pester older than 5.3.0 is not handed on'
Assert-Equal -Expected $null -Actual $nothing -Message 'and with none loaded there is nothing to hand on'

# Cleanup
Remove-TestRunnerSandbox -Path $sandbox

exit (Complete-TestRun)
