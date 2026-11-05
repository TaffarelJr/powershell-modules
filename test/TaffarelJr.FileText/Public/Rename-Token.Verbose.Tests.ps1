#Requires -Version 7.4
using namespace System.IO
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'FileTextTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' '..' 'PreferenceTestHelper.ps1')
Install-VerboseCaller

$sandbox = New-FileTextSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $tree = Join-Path $sandbox 'direct'
    New-Item -ItemType Directory -Path $tree | Out-Null
    $file = Join-Path $tree 'PlaceholderFile.txt'
    [File]::WriteAllText($file, 'Placeholder private note', [UTF8Encoding]::new($false))

    # Act
    $all = @(Get-VerboseLine { Rename-Token -Path $tree -From 'Placeholder' -To 'Real' -Verbose })
    $lines = @($all | Where-Object { $_ -match '^(Writing|Renaming) ' })

    # Assert
    Assert-Equal -Expected @("Writing 17 bytes to '$file' as utf-8.", "Renaming '$file' to 'RealFile.txt'.") `
        -Actual $lines -Message '-Verbose names each file it writes and each item it renames, in that order'
    Assert-Equal -Expected 0 -Actual @($all | Where-Object { $_ -like '*private note*' }).Count `
        -Message 'and no verbose line holds any of their text'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $other = Join-Path $sandbox 'caller'
    New-Item -ItemType Directory -Path $other | Out-Null
    $otherFile = Join-Path $other 'PlaceholderFile.txt'
    [File]::WriteAllText($otherFile, 'Placeholder', [UTF8Encoding]::new($false))

    # Act - the switch given to a command of another module, which calls this one without it
    $all = @(Get-VerboseLine { Invoke-RenameTokenCaller -Path $other -From 'Placeholder' -To 'Real' -Verbose })
    $lines = @($all | Where-Object { $_ -match '^(Writing|Renaming) ' })

    # Assert
    Assert-Equal -Expected @("Writing 4 bytes to '$otherFile' as utf-8.", "Renaming '$otherFile' to 'RealFile.txt'.") `
        -Actual $lines -Message 'A call made from another module under -Verbose is named too'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $quiet = Join-Path $sandbox 'quiet'
    New-Item -ItemType Directory -Path $quiet | Out-Null
    [File]::WriteAllText((Join-Path $quiet 'PlaceholderFile.txt'), 'Placeholder', [UTF8Encoding]::new($false))

    # Act
    $lines = @(Get-VerboseLine { Invoke-RenameTokenCaller -Path $quiet -From 'Placeholder' -To 'Real' })

    # Assert
    Assert-Equal -Expected 0 -Actual $lines.Count `
        -Message 'A call from another module that asked for nothing says nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $preview = Join-Path $sandbox 'preview'
    New-Item -ItemType Directory -Path $preview | Out-Null
    [File]::WriteAllText((Join-Path $preview 'PlaceholderFile.txt'), 'Placeholder', [UTF8Encoding]::new($false))

    # Act
    $all = @(Get-VerboseLine { Rename-Token -Path $preview -From 'Placeholder' -To 'Real' -Verbose -WhatIf })

    # Assert
    Assert-Equal -Expected 0 -Actual @($all | Where-Object { $_ -match '^(Writing|Renaming) ' }).Count `
        -Message 'Under -WhatIf nothing is written or renamed, so none is announced'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
