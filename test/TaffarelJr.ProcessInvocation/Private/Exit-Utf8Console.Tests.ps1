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
    # Arrange
    [Console]::OutputEncoding = [Encoding]::Latin1
    Enter-Utf8Console

    # Act
    Exit-Utf8Console

    # Assert
    Assert-Equal -Expected ([Encoding]::Latin1).CodePage -Actual ([Console]::OutputEncoding).CodePage `
        -Message 'The encoding from before the pin is restored'
    Assert-Equal -Expected 0 -Actual (Get-ConsoleEncodingGate).Depth -Message 'The gate has no holders left'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the pin taken from a console that was already UTF-8
    [Console]::OutputEncoding = [UTF8Encoding]::new($false)
    Enter-Utf8Console

    # Act
    Exit-Utf8Console

    # Assert
    Assert-Equal -Expected 65001 -Actual ([Console]::OutputEncoding).CodePage `
        -Message 'Letting go leaves an already-UTF-8 console as it was'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two holders
    [Console]::OutputEncoding = [Encoding]::Latin1
    Enter-Utf8Console
    Enter-Utf8Console

    # Act
    Exit-Utf8Console
    $afterFirst = [Console]::OutputEncoding.CodePage
    Exit-Utf8Console

    # Assert
    Assert-Equal -Expected 65001 -Actual $afterFirst `
        -Message 'The first holder letting go does not restore the encoding'
    Assert-Equal -Expected ([Encoding]::Latin1).CodePage -Actual ([Console]::OutputEncoding).CodePage `
        -Message 'The last holder letting go does'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a console whose input and output are both not UTF-8, pinned
    [Console]::OutputEncoding = [Encoding]::Latin1
    [Console]::InputEncoding = [Encoding]::Latin1
    Enter-Utf8Console

    # Act
    Exit-Utf8Console

    # Assert
    Assert-Equal -Expected ([Encoding]::Latin1).CodePage -Actual ([Console]::InputEncoding).CodePage `
        -Message 'The input encoding from before the pin is restored too'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two holders
    [Console]::InputEncoding = [Encoding]::Latin1
    Enter-Utf8Console
    Enter-Utf8Console

    # Act
    Exit-Utf8Console
    $inputAfterFirst = [Console]::InputEncoding.CodePage
    Exit-Utf8Console

    # Assert
    Assert-Equal -Expected 65001 -Actual $inputAfterFirst `
        -Message 'The first holder letting go does not restore the input encoding'
    Assert-Equal -Expected ([Encoding]::Latin1).CodePage -Actual ([Console]::InputEncoding).CodePage `
        -Message 'The last holder letting go does'
}
finally {
    [Console]::OutputEncoding = $originalEncoding
    [Console]::InputEncoding = $originalInputEncoding
}

exit (Complete-TestRun)
