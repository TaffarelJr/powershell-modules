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
    $tree = Join-Path $sandbox 'tree'
    $library = Join-Path $tree 'PlaceholderLibrary'
    $skipped = Join-Path $tree 'skipped'
    New-Item -ItemType Directory -Path $library, $skipped | Out-Null
    [File]::WriteAllText((Join-Path $tree 'a.txt'), 'Placeholder a')
    [File]::WriteAllText((Join-Path $tree 'Placeholder.md'), 'no token')
    [File]::WriteAllText((Join-Path $library 'b.txt'), 'b')
    [File]::WriteAllText((Join-Path $skipped 'Placeholder.txt'), 'Placeholder')
    $replace = "What if: Performing the operation ""Replace 'Placeholder'"" on target"

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-FileTextTreeState -Path $tree

    # Act
    $run = Get-WhatIfOutput {
        Rename-Token -Path $tree -From 'Placeholder' -To 'Real' -Exclude 'skipped' -WhatIf
    }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-FileTextTreeState -Path $tree) `
        -Message '-WhatIf edits no content and renames nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @(
        "$replace ""$(Join-Path $tree 'a.txt')""."
        "What if: Performing the operation ""Rename to 'RealLibrary'"" on target ""$library""."
        "What if: Performing the operation ""Rename to 'Real.md'"" on target ""$(Join-Path $tree 'Placeholder.md')""."
    ) -Actual $run.Messages `
        -Message '-WhatIf names each file it would edit and each item it would rename, outside -Exclude'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-FileTextTreeState -Path $tree

    # Act - a new name that contains the old one, allowed by -Force
    $run = Get-WhatIfOutput {
        Rename-Token -Path $tree -From 'Placeholder' -To 'PlaceholderLib' -SkipExtension '.txt' -Force -WhatIf
    }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-FileTextTreeState -Path $tree) `
        -Message '-WhatIf with -Force and -SkipExtension changes nothing either'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message 'and returns nothing'
    $rename = 'What if: Performing the operation "Rename to'
    Assert-Equal -Expected @(
        "$rename 'PlaceholderLib.txt'"" on target ""$(Join-Path $skipped 'Placeholder.txt')""."
        "$rename 'PlaceholderLibLibrary'"" on target ""$library""."
        "$rename 'PlaceholderLib.md'"" on target ""$(Join-Path $tree 'Placeholder.md')""."
    ) -Actual $run.Messages -Message 'and names only renames: no content of a skipped extension is edited'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-FileTextTreeState -Path $tree

    # Act - nothing to do
    $run = Get-WhatIfOutput { Rename-Token -Path $tree -From 'Absent' -To 'Other' -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-FileTextTreeState -Path $tree) `
        -Message '-WhatIf with a token found nowhere changes nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message 'and returns nothing, not a summary of zeroes'
    Assert-Equal -Expected @() -Actual $run.Messages -Message 'and names nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $run = Get-WhatIfOutput { Rename-Token -Path $tree -From 'Placeholder' -To 'Placeholder' -WhatIf }

    # Assert
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf with -From equal to -To returns nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Rename-Token -Path $tree -From 'Placeholder' -To 'PlaceholderLib' -WhatIf } `
        -MessageLike '*the new name contains the old one*Pass -Force*' `
        -Message '-WhatIf still refuses a new name that contains the old one'
    Assert-Throws -ScriptBlock { Rename-Token -Path (Join-Path $sandbox 'nope') -From 'a' -To 'b' -WhatIf } `
        -MessageLike "*'*nope' is not a folder.*" -Message 'and still refuses a folder that is not there'
    Assert-Equal -Expected $before -Actual (Get-FileTextTreeState -Path $tree) -Message 'and changes nothing doing so'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - -Confirm in a fresh non-interactive process, where the
    # confirmation prompt fails instead of waiting for an answer
    $confirmTree = Join-Path $sandbox 'confirm'
    New-Item -ItemType Directory -Path $confirmTree | Out-Null
    [File]::WriteAllText((Join-Path $confirmTree 'a.txt'), 'Placeholder a')
    [File]::WriteAllText((Join-Path $confirmTree 'b.txt'), 'Placeholder b')
    $confirmScript = Join-Path $sandbox 'Invoke-Confirm.ps1'
    [File]::WriteAllText($confirmScript, @'
param($RepoRoot, $Tree)
Import-Module (Join-Path $RepoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
try {
    Rename-Token -Path $Tree -From 'Placeholder' -To 'Real' -Confirm
    'nothing'
}
catch {
    $_.Exception.Message
}
'@)
    $before = Get-FileTextTreeState -Path $confirmTree

    # Act
    $thrown = (& pwsh -NoProfile -NonInteractive -File $confirmScript $repoRoot $confirmTree) -join "`n"

    # Assert
    Assert-That -Condition ($thrown -like 'Exception calling "ShouldProcess"*NonInteractive*') `
        -Message 'a confirmation prompt that cannot be shown stops the run with its own error, not a failure per file'
    Assert-Equal -Expected $before -Actual (Get-FileTextTreeState -Path $confirmTree) `
        -Message 'and nothing is changed'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - -Confirm in a fresh process, with exactly one yes for the
    # content and one for the name; a third question would find no answer
    $answerTree = Join-Path $sandbox 'answer'
    New-Item -ItemType Directory -Path $answerTree | Out-Null
    [File]::WriteAllText((Join-Path $answerTree 'Placeholder.txt'), 'Placeholder')
    $answerScript = Join-Path $sandbox 'Invoke-ConfirmAnswer.ps1'
    [File]::WriteAllText($answerScript, @'
param($RepoRoot, $Tree)
Import-Module (Join-Path $RepoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
$outcome = try {
    $result = Rename-Token -Path $Tree -From 'Placeholder' -To 'Real' -Confirm
    "$($result.FilesEdited) edited, $($result.PathsRenamed) renamed"
}
catch {
    $_.Exception.Message
}
"OUTCOME: $outcome"
'@)

    # Act
    $answered = "y`ny" | & pwsh -NoProfile -File $answerScript $repoRoot $answerTree

    # Assert
    Assert-Equal -Expected @('OUTCOME: 1 edited, 1 renamed') -Actual @($answered -like 'OUTCOME: *') `
        -Message 'one yes per change is enough: the file is written and renamed without asking again'
    Assert-Equal -Expected @('Real.txt = 5265616C') -Actual @(Get-FileTextTreeState -Path $answerTree) `
        -Message 'and the tree holds the new name and content'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
