#Requires -Version 7.4
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
foreach ($name in 'Get-ConsoleEncodingGate', 'Enter-Utf8Console', 'Exit-Utf8Console') {
    . (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/Private' "$name.ps1")
}

$originalEncoding = [Console]::OutputEncoding
$originalInputEncoding = [Console]::InputEncoding
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a console that is not UTF-8
    [Console]::OutputEncoding = [Encoding]::Latin1

    # Act
    Enter-Utf8Console
    $pinned = [Console]::OutputEncoding.CodePage
    Exit-Utf8Console

    # Assert
    Assert-Equal -Expected 65001 -Actual $pinned -Message 'The console is UTF-8 while pinned'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    [Console]::OutputEncoding = [Encoding]::Latin1

    # Act - two holders, the first of which lets go early
    Enter-Utf8Console
    Enter-Utf8Console
    Exit-Utf8Console
    $stillPinned = [Console]::OutputEncoding.CodePage
    Exit-Utf8Console

    # Assert
    Assert-Equal -Expected 65001 -Actual $stillPinned -Message 'The pin holds until the last holder lets go'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a console that is already UTF-8
    [Console]::OutputEncoding = [UTF8Encoding]::new($false)

    # Act
    Enter-Utf8Console
    $pinned = [Console]::OutputEncoding.CodePage
    Exit-Utf8Console

    # Assert
    Assert-Equal -Expected 65001 -Actual $pinned -Message 'A console that is already UTF-8 stays UTF-8'
    Assert-Equal -Expected 0 -Actual (Get-ConsoleEncodingGate).Depth -Message 'Every enter has been matched by an exit'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a console whose input is not UTF-8 either
    [Console]::OutputEncoding = [Encoding]::Latin1
    [Console]::InputEncoding = [Encoding]::Latin1

    # Act
    Enter-Utf8Console
    $pinnedInput = [Console]::InputEncoding.CodePage
    Exit-Utf8Console

    # Assert
    Assert-Equal -Expected 65001 -Actual $pinnedInput `
        -Message 'The console''s input is UTF-8 while pinned, so a child reads the UTF-8 it is sent as UTF-8'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a console whose output is already UTF-8 but whose input is not
    [Console]::OutputEncoding = [UTF8Encoding]::new($false)
    [Console]::InputEncoding = [Encoding]::Latin1

    # Act
    Enter-Utf8Console
    $pinnedInput = [Console]::InputEncoding.CodePage
    Exit-Utf8Console

    # Assert
    Assert-Equal -Expected 65001 -Actual $pinnedInput -Message 'The input is pinned whatever the output was'
}
finally {
    [Console]::OutputEncoding = $originalEncoding
    [Console]::InputEncoding = $originalInputEncoding
}

exit (Complete-TestRun)
