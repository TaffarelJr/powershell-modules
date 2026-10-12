#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.VSCode/TaffarelJr.VSCode.psd1') -Force
. (Join-Path $PSScriptRoot 'VSCodeTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'PreferenceTestHelper.ps1')

$module = Get-Module TaffarelJr.VSCode
$sandbox = New-VSCodeSandbox
$repo = Join-Path $sandbox.Root 'work' 'repo'
New-Item -ItemType Directory -Path $repo | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $path = Join-Path $sandbox.Root 'work' 'new.code-workspace'

    # Act
    $run = Get-WhatIfOutput {
        Invoke-WhatIfCaller -Call { New-VSCodeWorkspaceFile -Path $path -Folder $repo } -WhatIf
    }

    # Assert
    Assert-That -Condition (-not (Test-Path -LiteralPath $path)) `
        -Message 'New-VSCodeWorkspaceFile called from a command run with -WhatIf writes no file'
    Assert-Equal -Expected @("What if: Performing the operation ""Write workspace file"" on target ""$path"".") `
        -Actual $run.Messages -Message 'and says which file it would have written'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a Stable install, and a launcher that records
    $null = Add-FakeVSCode -Fixture $sandbox
    Install-FakeVSCodeLauncher -Module $module

    # Act
    $run = Get-WhatIfOutput { Invoke-WhatIfCaller -Call { Start-VSCode -Path $repo } -WhatIf }

    # Assert
    Assert-Equal -Expected @() -Actual @(Get-FakeVSCodeLaunch -Module $module) `
        -Message 'Start-VSCode called from a command run with -WhatIf launches nothing'
    Assert-Equal -Expected @("What if: Performing the operation ""Open in VS Code"" on target ""$repo"".") `
        -Actual $run.Messages -Message 'and says what it would have opened'
}
finally {
    Remove-VSCodeSandbox -Fixture $sandbox
}

exit (Complete-TestRun)
