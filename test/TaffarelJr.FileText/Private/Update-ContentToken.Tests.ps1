#Requires -Version 7.4
using namespace System.IO
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'FileTextTestHelper.ps1')
$module = Get-Module TaffarelJr.FileText

function Update-Content([object[]]$Item, [string[]]$SkipExtension = @()) {
    & $module {
        [CmdletBinding()]
        param($i, $s)
        Update-ContentToken -Item $i -From 'Placeholder' -To 'Real' -SkipExtension $s -Cmdlet $PSCmdlet
    } $Item $SkipExtension
}

$sandbox = New-FileTextSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - one file with the token, one without, one binary with the token
    $mixed = Join-Path $sandbox 'mixed'
    New-Item -ItemType Directory -Path $mixed | Out-Null
    $withToken = Join-Path $mixed 'with-token.txt'
    [File]::WriteAllText($withToken, 'Placeholder')
    $withoutToken = Join-Path $mixed 'without-token.txt'
    [File]::WriteAllText($withoutToken, 'nothing here')
    $binary = New-TestFile -Directory $mixed -Name 'binary.dat' `
        -Byte ([byte[]](0x50, 0x6C, 0x61, 0x63, 0x65, 0x68, 0x6F, 0x6C, 0x64, 0x65, 0x72, 0x00))
    $binaryBefore = [File]::ReadAllBytes($binary)

    # Act
    $result = Update-Content -Item @(Get-ChildItem -LiteralPath $mixed -File)

    # Assert
    Assert-Equal -Expected 1 -Actual $result.Edited -Message 'Only the file genuinely containing the token is edited'
    Assert-Equal -Expected 'Real' -Actual ([File]::ReadAllText($withToken)) -Message 'and has the token replaced'
    Assert-Equal -Expected 'nothing here' -Actual ([File]::ReadAllText($withoutToken)) `
        -Message 'A file without the token is left alone'
    Assert-Equal -Expected @("Skipped binary content: $binary") -Actual @($result.Warning) `
        -Message 'The binary file is reported, by path, as skipped'
    Assert-Equal -Expected $binaryBefore -Actual ([File]::ReadAllBytes($binary)) -Message 'and its bytes are untouched'
    Assert-Equal -Expected 0 -Actual @($result.Failed).Count -Message 'Nothing here is a failure'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file with a skipped extension, in either case
    $skip = Join-Path $sandbox 'skip'
    New-Item -ItemType Directory -Path $skip | Out-Null
    [File]::WriteAllText((Join-Path $skip 'image.png'), 'Placeholder')
    [File]::WriteAllText((Join-Path $skip 'LOUD.PNG'), 'Placeholder')

    # Act
    $skipped = Update-Content -Item @(Get-ChildItem -LiteralPath $skip -File) -SkipExtension @('.png')

    # Assert
    Assert-Equal -Expected 0 -Actual $skipped.Edited `
        -Message 'A skip-extension file is excluded before it is even read, whatever its case'
    Assert-Equal -Expected 'Placeholder' -Actual ([File]::ReadAllText((Join-Path $skip 'image.png'))) `
        -Message 'and its content is untouched'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a read-only file with the token beside an ordinary one
    $locked = Join-Path $sandbox 'locked'
    New-Item -ItemType Directory -Path $locked | Out-Null
    $lockedFile = Join-Path $locked 'a-locked.txt'
    [File]::WriteAllText($lockedFile, 'Placeholder')
    Set-ItemProperty -LiteralPath $lockedFile -Name IsReadOnly -Value $true
    [File]::WriteAllText((Join-Path $locked 'b-normal.txt'), 'Placeholder')

    # Act
    $failed = Update-Content -Item @(Get-ChildItem -LiteralPath $locked -File)

    # Assert
    Assert-Equal -Expected 1 -Actual $failed.Edited -Message 'The file that can be written is still done'
    Assert-Equal -Expected 1 -Actual @($failed.Failed).Count -Message 'and the one that cannot is a failure'
    Assert-That -Condition ($failed.Failed[0] -like "$lockedFile - *denied*") `
        -Message 'recorded as its path, a dash, and why'
    Assert-Equal -Expected 'Placeholder' -Actual ([File]::ReadAllText($lockedFile)) `
        -Message 'with its content as it was'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - Windows-1252 text with the token, and some without
    $legacy = Join-Path $sandbox 'legacy'
    New-Item -ItemType Directory -Path $legacy | Out-Null
    $latinWith = New-TestFile -Directory $legacy -Name 'with.txt' `
        -Byte ([Encoding]::GetEncoding(28591).GetBytes("caf$([char]0xE9) Placeholder"))
    $null = New-TestFile `
        -Directory $legacy `
        -Name 'without.txt' `
        -Byte ([Encoding]::GetEncoding(28591).GetBytes("caf$([char]0xE9)"))
    $withBefore = [File]::ReadAllBytes($latinWith)

    # Act
    $legacyResult = Update-Content -Item @(Get-ChildItem -LiteralPath $legacy -File)

    # Assert
    Assert-Equal -Expected 0 -Actual $legacyResult.Edited -Message 'Neither is edited'
    Assert-Equal -Expected 1 -Actual @($legacyResult.Failed).Count `
        -Message 'but only the one with the token is a failure'
    Assert-That -Condition ($legacyResult.Failed[0] -like "$latinWith - *is not valid utf-8 text*") `
        -Message 'which says why'
    Assert-Equal -Expected $withBefore -Actual ([File]::ReadAllBytes($latinWith)) -Message 'and its bytes are untouched'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file with a second name, a hard link, elsewhere
    $hard = Join-Path $sandbox 'hard'
    New-Item -ItemType Directory -Path $hard | Out-Null
    $hardFile = Join-Path $hard 'a.txt'
    [File]::WriteAllText($hardFile, 'Placeholder')
    $null = New-Item -ItemType HardLink -Path (Join-Path $sandbox 'other-name.txt') -Target $hardFile

    # Act
    $hardResult = Update-Content -Item @(Get-ChildItem -LiteralPath $hard -File)

    # Assert
    Assert-Equal -Expected 1 -Actual $hardResult.Edited -Message 'A hard-linked file is an ordinary file, and is edited'
    Assert-Equal -Expected 'Real' -Actual ([File]::ReadAllText($hardFile)) -Message 'rather than skipped as a link'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - items that are folders, and no items at all
    $folderOnly = Join-Path $sandbox 'folder-only'
    New-Item -ItemType Directory -Path (Join-Path $folderOnly 'Placeholder') | Out-Null

    # Act
    $folders = Update-Content -Item @(Get-ChildItem -LiteralPath $folderOnly)
    $nothing = Update-Content -Item @()

    # Assert
    Assert-Equal -Expected 0 -Actual $folders.Edited -Message 'A folder is not a file to edit'
    Assert-Equal -Expected 0 -Actual $nothing.Edited -Message 'and no items is no work, not an error'
    Assert-Equal -Expected 0 -Actual @($nothing.Failed).Count -Message 'with nothing failed'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two files with the token, and a caller that cannot ask
    $unasked = Join-Path $sandbox 'unasked'
    New-Item -ItemType Directory -Path $unasked | Out-Null
    [File]::WriteAllText((Join-Path $unasked 'a.txt'), 'Placeholder')
    [File]::WriteAllText((Join-Path $unasked 'b.txt'), 'Placeholder')
    $unaskedItems = @(Get-ChildItem -LiteralPath $unasked -File)
    $cannotAsk = New-UnaskableCmdlet -Message 'No one can answer the prompt.'
    $before = Get-FileTextTreeState -Path $unasked
    $call = {
        & $module {
            param($i, $c)
            Update-ContentToken -Item $i -From 'Placeholder' -To 'Real' -SkipExtension @() -Cmdlet $c
        } $unaskedItems $cannotAsk
    }

    # Act / Assert
    Assert-Throws -ScriptBlock $call -MessageLike 'No one can answer the prompt.' `
        -Message 'A prompt that cannot be shown stops the pass with its own error, not a failure per file'
    Assert-Equal -Expected $before -Actual (Get-FileTextTreeState -Path $unasked) -Message 'and nothing is changed'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
