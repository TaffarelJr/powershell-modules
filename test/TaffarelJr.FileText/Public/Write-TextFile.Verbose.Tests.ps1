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
    $path = Join-Path $sandbox 'verbose.txt'

    # Act
    $all = @(Get-VerboseLine { Write-TextFile -Path $path -Content 'the secret text' -Verbose })
    $lines = @($all | Where-Object { $_ -like 'Writing *' })

    # Assert
    Assert-Equal -Expected @("Writing 15 bytes to '$path' as utf-8.") -Actual $lines `
        -Message '-Verbose names the file about to be written, once, with its size and encoding'
    Assert-Equal -Expected 0 -Actual @($all | Where-Object { $_ -like '*secret*' }).Count `
        -Message 'and no verbose line holds any of its text'
    Assert-Equal -Expected 'the secret text' -Actual ([File]::ReadAllText($path)) `
        -Message 'and the file is written as usual'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $quiet = Join-Path $sandbox 'quiet.txt'

    # Act
    $lines = @(Get-VerboseLine { Write-TextFile -Path $quiet -Content 'x' })

    # Assert
    Assert-Equal -Expected 0 -Actual $lines.Count -Message 'Without -Verbose nothing is said'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $viaCaller = Join-Path $sandbox 'via-caller.txt'

    # Act - the verbose switch given to a command of another module, which calls this one without it
    $lines = @(Get-VerboseLine { Invoke-WriteTextFileCaller -Path $viaCaller -Content 'x' -Verbose })

    # Assert
    Assert-Equal -Expected @("Writing 1 bytes to '$viaCaller' as utf-8.") -Actual $lines `
        -Message 'A call made from another module under -Verbose is named too'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $viaPreference = Join-Path $sandbox 'via-preference.txt'

    # Act - the verbose preference of the session, with the caller given no switch
    $previous = (Get-Variable -Name VerbosePreference -Scope Global).Value
    Set-Variable -Name VerbosePreference -Scope Global -Value 'Continue'
    try {
        $lines = @(Get-VerboseLine { Invoke-WriteTextFileCaller -Path $viaPreference -Content 'x' })
    }
    finally {
        Set-Variable -Name VerbosePreference -Scope Global -Value $previous
    }

    # Assert
    Assert-Equal -Expected @("Writing 1 bytes to '$viaPreference' as utf-8.") -Actual $lines `
        -Message 'and so is one made under the session''s verbose preference'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $viaQuiet = Join-Path $sandbox 'via-quiet.txt'

    # Act
    $lines = @(Get-VerboseLine { Invoke-WriteTextFileCaller -Path $viaQuiet -Content 'x' })

    # Assert
    Assert-Equal -Expected 0 -Actual $lines.Count `
        -Message 'A call from another module that asked for nothing says nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $viaOff = Join-Path $sandbox 'via-off.txt'

    # Act - the caller's session asks for verbose output, and the call itself turns it off
    $previous = (Get-Variable -Name VerbosePreference -Scope Global).Value
    Set-Variable -Name VerbosePreference -Scope Global -Value 'Continue'
    try {
        $lines = @(Get-VerboseLine { Write-TextFile -Path $viaOff -Content 'x' -Verbose:$false })
    }
    finally {
        Set-Variable -Name VerbosePreference -Scope Global -Value $previous
    }

    # Assert
    Assert-Equal -Expected 0 -Actual $lines.Count -Message '-Verbose:$false on the call itself wins over the session'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $skipped = Join-Path $sandbox 'skipped.txt'

    # Act
    $lines = @(Get-VerboseLine { Write-TextFile -Path $skipped -Content 'x' -Verbose -WhatIf })

    # Assert
    Assert-Equal -Expected 0 -Actual $lines.Count -Message 'A write that -WhatIf skips is not announced as written'
    Assert-That -Condition (-not (Test-Path -LiteralPath $skipped)) -Message 'and the file is not created'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
