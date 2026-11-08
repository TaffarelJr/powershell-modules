#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.VSCode/TaffarelJr.VSCode.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

$module = Get-Module TaffarelJr.VSCode
$sandbox = New-VSCodeSandbox
$repo = Join-Path $sandbox.Root 'work' 'repo'
$other = Join-Path $sandbox.Root 'work' 'other'
New-Item -ItemType Directory -Path $repo, $other | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a Stable install, and a launcher that records
    $null = Add-FakeVSCode -Fixture $sandbox
    Install-FakeVSCodeLauncher -Module $module

    # Act
    $run = Get-WhatIfOutput { Start-VSCode -Path $repo -WhatIf }

    # Assert
    Assert-Equal -Expected @() -Actual @(Get-FakeVSCodeLaunch -Module $module) -Message '-WhatIf launches nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @("What if: Performing the operation ""Open in VS Code"" on target ""$repo"".") `
        -Actual $run.Messages -Message '-WhatIf names what it would open'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two folders from the pipeline, with -Window and -Edition
    Install-FakeVSCodeLauncher -Module $module
    $folders = @(Get-Item -LiteralPath $repo, $other)

    # Act
    $run = Get-WhatIfOutput { $folders | Start-VSCode -Window New -Edition Stable -WhatIf }

    # Assert
    Assert-Equal -Expected @() -Actual @(Get-FakeVSCodeLaunch -Module $module) `
        -Message '-WhatIf with piped folders, -Window and -Edition launches nothing'
    Assert-Equal `
        -Expected @("What if: Performing the operation ""Open in VS Code (Stable)"" on target ""$repo, $other"".") `
        -Actual $run.Messages `
        -Message 'and names both folders, for the one launch it would make'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - nothing installed
    Reset-VSCodeSandbox -Fixture $sandbox
    Install-FakeVSCodeLauncher -Module $module

    # Act / Assert
    Assert-Throws -ScriptBlock { Start-VSCode -Path $repo -WhatIf } `
        -MessageLike 'VS Code was not found.*' `
        -Message '-WhatIf still says when VS Code is not installed'
    Assert-Throws -ScriptBlock { Start-VSCode -Path ' ' -WhatIf } `
        -MessageLike '-Path is empty or only whitespace.*' `
        -Message 'and still refuses a blank path'
    Assert-Equal -Expected @() -Actual @(Get-FakeVSCodeLaunch -Module $module) -Message 'and launches nothing'
}
finally {
    Remove-VSCodeSandbox -Fixture $sandbox
}

exit (Complete-TestRun)
