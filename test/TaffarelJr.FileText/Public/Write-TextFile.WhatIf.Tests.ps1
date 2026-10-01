#Requires -Version 7.4
using namespace System.IO
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'FileTextTestHelper.ps1')

$sandbox = New-FileTextSandbox
try {
    $existing = Join-Path $sandbox 'existing.txt'
    [File]::WriteAllText($existing, "old`r`n", [UTF8Encoding]::new($true))

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-FileTextTreeState -Path $sandbox

    # Act
    $run = Get-WhatIfOutput { Write-TextFile -Path $existing -Content 'new' -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-FileTextTreeState -Path $sandbox) `
        -Message '-WhatIf leaves an existing file as it was'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @("What if: Performing the operation ""Write file"" on target ""$existing"".") `
        -Actual $run.Messages -Message '-WhatIf names the file it would write, and not its text'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-FileTextTreeState -Path $sandbox
    $created = Join-Path $sandbox 'created.txt'

    # Act - new lines shaped like a sibling
    $run = Get-WhatIfOutput {
        Write-TextFile -Path $created -Line @('a', 'b') -LikeFilePath $existing -Encoding ([Encoding]::ASCII) -WhatIf
    }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-FileTextTreeState -Path $sandbox) `
        -Message '-WhatIf with -Line, -LikeFilePath and -Encoding creates no file'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message 'and returns nothing'
    Assert-Equal -Expected @("What if: Performing the operation ""Write file"" on target ""$created"".") `
        -Actual $run.Messages -Message 'and names the file it would create'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file in two folders that are not there
    $before = Get-FileTextTreeState -Path $sandbox
    $deep = Join-Path $sandbox 'a' 'b' 'deep.txt'

    # Act
    $run = Get-WhatIfOutput { Write-TextFile -Path $deep -Content 'x' -CreateDirectory -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-FileTextTreeState -Path $sandbox) `
        -Message '-WhatIf with -CreateDirectory makes no folder and no file'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message 'and returns nothing'
    Assert-Equal -Expected @("What if: Performing the operation ""Write file"" on target ""$deep"".") `
        -Actual $run.Messages -Message 'and names the file it would write'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $legacy = New-TestFile -Directory $sandbox -Name 'legacy.txt' `
        -Byte ([Encoding]::GetEncoding(28591).GetBytes("caf$([char]0xE9)"))
    $before = Get-FileTextTreeState -Path $sandbox

    # Act / Assert
    Assert-Throws -ScriptBlock { Write-TextFile -Path $legacy -Content 'x' -WhatIf } `
        -MessageLike "*legacy.txt'*no byte order mark*" `
        -Message '-WhatIf still refuses a file whose encoding cannot be told'
    Assert-Throws -ScriptBlock { Write-TextFile -Path $existing -Content "a$([char]0xD800)b" -WhatIf } `
        -MessageLike '*translate Unicode character*' `
        -Message 'and still refuses text the encoding cannot hold'
    Assert-Throws -ScriptBlock { Write-TextFile -Path $sandbox -Content 'x' -WhatIf } `
        -MessageLike '*is a folder, not a file*' `
        -Message 'and still refuses a folder'
    Assert-Equal -Expected $before -Actual (Get-FileTextTreeState -Path $sandbox) `
        -Message 'and changes nothing doing so'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
