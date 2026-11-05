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
    $path = Join-Path $sandbox 'file.txt'
    [File]::WriteAllText($path, 'Hello Placeholder', [UTF8Encoding]::new($false))

    # Act
    $all = @(Get-VerboseLine { Update-FileToken -Path $path -From 'Placeholder' -To 'Real' -Verbose })
    $lines = @($all | Where-Object { $_ -like 'Writing *' })

    # Assert
    Assert-Equal -Expected @("Writing 10 bytes to '$path' as utf-8.") -Actual $lines `
        -Message '-Verbose names the file it rewrites, with its size and encoding, and nothing of its text'
    Assert-Equal -Expected 0 -Actual @($all | Where-Object { $_ -like '*Hello*' }).Count `
        -Message 'and no verbose line holds any of its text'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $other = Join-Path $sandbox 'other.txt'
    [File]::WriteAllText($other, 'Hello Placeholder', [UTF8Encoding]::new($false))

    # Act - the switch given to a command of another module, which calls this one without it
    $all = @(Get-VerboseLine { Invoke-UpdateFileTokenCaller -Path $other -From 'Placeholder' -To 'Real' -Verbose })
    $lines = @($all | Where-Object { $_ -like 'Writing *' })

    # Assert
    Assert-Equal -Expected @("Writing 10 bytes to '$other' as utf-8.") -Actual $lines `
        -Message 'A call made from another module under -Verbose is named too'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $quiet = Join-Path $sandbox 'quiet.txt'
    [File]::WriteAllText($quiet, 'Hello Placeholder', [UTF8Encoding]::new($false))

    # Act
    $lines = @(Get-VerboseLine { Invoke-UpdateFileTokenCaller -Path $quiet -From 'Placeholder' -To 'Real' })

    # Assert
    Assert-Equal -Expected 0 -Actual $lines.Count `
        -Message 'A call from another module that asked for nothing says nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $without = Join-Path $sandbox 'without.txt'
    [File]::WriteAllText($without, 'no token here', [UTF8Encoding]::new($false))

    # Act
    $all = @(Get-VerboseLine { Update-FileToken -Path $without -From 'Placeholder' -To 'Real' -Verbose })

    # Assert
    Assert-Equal -Expected 0 -Actual @($all | Where-Object { $_ -like 'Writing *' }).Count `
        -Message 'A file without the token is not written, so none is announced'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
