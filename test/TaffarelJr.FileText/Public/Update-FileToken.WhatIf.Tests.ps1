#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'FileTextTestHelper.ps1')

$sandbox = New-FileTextSandbox
try {
    [File]::WriteAllText((Join-Path $sandbox 'a.txt'), 'Placeholder a')
    [File]::WriteAllText((Join-Path $sandbox 'b.txt'), 'b')
    [File]::WriteAllText((Join-Path $sandbox 'c.txt'), 'Placeholder c')
    $a = Join-Path $sandbox 'a.txt'
    $c = Join-Path $sandbox 'c.txt'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-FileTextTreeState -Path $sandbox

    # Act
    $run = Get-WhatIfOutput { Update-FileToken -Path $a -From 'Placeholder' -To 'Real' -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-FileTextTreeState -Path $sandbox) -Message '-WhatIf rewrites no file'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal `
        -Expected @("What if: Performing the operation ""Replace 'Placeholder'"" on target ""$a"".") `
        -Actual $run.Messages `
        -Message '-WhatIf names the file it would rewrite, and not what it would write'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-FileTextTreeState -Path $sandbox

    # Act - a file without the token
    $run = Get-WhatIfOutput {
        Update-FileToken -Path (Join-Path $sandbox 'b.txt') -From 'Placeholder' -To 'Real' -WhatIf
    }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-FileTextTreeState -Path $sandbox) `
        -Message '-WhatIf on a file without the token changes nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message 'and returns nothing, not $false'
    Assert-Equal -Expected @() -Actual $run.Messages -Message 'and names no file, since none would change'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-FileTextTreeState -Path $sandbox
    $listed = @(Get-ChildItem -LiteralPath $sandbox -File | Sort-Object Name)

    # Act - three files from the pipeline, one of them without the token
    $run = Get-WhatIfOutput { $listed | Update-FileToken -From 'Placeholder' -To '' -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-FileTextTreeState -Path $sandbox) `
        -Message '-WhatIf with an empty -To rewrites none of the piped files'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message 'and returns nothing for any of them'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Replace 'Placeholder'"" on target ""$a""."
        "What if: Performing the operation ""Replace 'Placeholder'"" on target ""$c""."
    ) -Actual $run.Messages -Message 'and names each piped file that holds the token'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Update-FileToken -Path (Join-Path $sandbox 'nope.txt') -From 'a' -To 'b' -WhatIf
    } -MessageLike "No such file: '*nope.txt'*" -Message '-WhatIf still says a missing file is missing'
    Assert-Throws -ScriptBlock { Update-FileToken -Path $sandbox -From 'a' -To 'b' -WhatIf } `
        -MessageLike '*is a folder, not a file*' -Message 'and still refuses a folder'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $result = Update-FileToken -Path $a -From 'Placeholder' -To 'Real' -WhatIf:$false

    # Assert
    Assert-Equal -Expected $true -Actual $result -Message '-WhatIf:$false rewrites the file and says so'
    Assert-Equal -Expected 'Real a' -Actual ([File]::ReadAllText($a)) -Message 'with the token replaced'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
