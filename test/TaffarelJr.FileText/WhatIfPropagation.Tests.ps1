#Requires -Version 7.4
using namespace System.IO
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot 'FileTextTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'PreferenceTestHelper.ps1')

$sandbox = New-FileTextSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $file = Join-Path $sandbox 'file.txt'
    [File]::WriteAllText($file, 'old')
    $before = Get-FileTextTreeState -Path $sandbox

    # Act
    $run = Get-WhatIfOutput {
        Invoke-WhatIfCaller -Call { Write-TextFile -Path $file -Content 'changed' } -WhatIf
    }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-FileTextTreeState -Path $sandbox) `
        -Message 'Write-TextFile called from a command run with -WhatIf writes nothing'
    Assert-Equal -Expected @("What if: Performing the operation ""Write file"" on target ""$file"".") `
        -Actual $run.Messages -Message 'and says what it would have written'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $holder = Join-Path $sandbox 'holder.txt'
    [File]::WriteAllText($holder, 'Placeholder')
    $before = Get-FileTextTreeState -Path $sandbox

    # Act
    $run = Get-WhatIfOutput {
        Invoke-WhatIfCaller -Call {
            Update-FileToken -Path $holder -From 'Placeholder' -To 'Real'
        } -WhatIf
    }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-FileTextTreeState -Path $sandbox) `
        -Message 'Update-FileToken called from a command run with -WhatIf rewrites nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message 'and returns nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $tree = Join-Path $sandbox 'tree'
    New-Item -ItemType Directory -Path $tree | Out-Null
    [File]::WriteAllText((Join-Path $tree 'PlaceholderNotes.txt'), 'Placeholder')
    $before = Get-FileTextTreeState -Path $sandbox

    # Act
    $run = Get-WhatIfOutput {
        Invoke-WhatIfCaller -Call {
            Rename-Token -Path $tree -From 'Placeholder' -To 'Real'
        } -WhatIf
    }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-FileTextTreeState -Path $sandbox) `
        -Message 'Rename-Token called from a command run with -WhatIf changes no content and no name'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message 'and returns nothing'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
