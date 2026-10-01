#Requires -Version 7.4
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'FileTextTestHelper.ps1')

$sandbox = New-FileTextSandbox
try {
    # Windows-1252 text that holds the token: refused, because rewriting it would replace each such character
    $legacyBytes = [Encoding]::GetEncoding(28591).GetBytes("caf$([char]0xE9) Placeholder")
    $legacy = New-TestFile -Directory $sandbox -Name 'legacy.txt' -Byte $legacyBytes

    foreach ($preference in 'SilentlyContinue', 'Ignore') {
        #───────────────────────────────────────────────────────────────────────
        # Act - a failing call whose caller asked for errors to be hidden
        $output = @()
        $caught = $null
        try {
            $output = @(Update-FileToken -Path $legacy -From 'Placeholder' -To 'Real' -ErrorAction $preference)
        }
        catch {
            $caught = $_
        }

        # Assert
        Assert-Equal -Expected $legacyBytes -Actual ([File]::ReadAllBytes($legacy)) `
            -Message "Under -ErrorAction $preference a failing file is still not rewritten"
        Assert-Equal -Expected 0 -Actual $output.Count -Message 'and nothing is returned for it'
        Assert-Equal -Expected 'RuntimeException,Update-FileToken' -Actual $caught.FullyQualifiedErrorId `
            -Message 'and the failure is still raised, as a terminating error'
    }

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $caught = $null
    try {
        Update-FileToken -Path $legacy -From 'Placeholder' -To 'Real'
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected 'RuntimeException,Update-FileToken' -Actual $caught.FullyQualifiedErrorId `
        -Message 'A failing file raises a terminating error whose ID is the failure kind and the command'
    Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
        -Message 'with a category a caller can act on'
    Assert-Equal -Expected $caught.Exception.Message -Actual $caught.TargetObject `
        -Message 'and the target the failure had, which is its message'
    $messagePattern = "'$([WildcardPattern]::Escape($legacy))' is not valid utf-8 text: *"
    Assert-That -Condition ($caught.Exception.Message -like $messagePattern) `
        -Message 'and the message of the failure, naming the file'
    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Update-FileToken -Path $legacy -From 'Placeholder' -To 'Real' -ErrorAction Stop } `
        -MessageLike "*legacy.txt'*is not valid utf-8 text*" `
        -Message 'Under -ErrorAction Stop a failing file still throws'
    Assert-Equal -Expected $legacyBytes -Actual ([File]::ReadAllBytes($legacy)) `
        -Message 'and is left exactly as it was'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a good file, the failing one, and another good file, in that order
    $first = New-TestFile -Directory $sandbox -Name 'first.txt' -Byte ([Encoding]::UTF8.GetBytes('Placeholder one'))
    $last = New-TestFile -Directory $sandbox -Name 'last.txt' -Byte ([Encoding]::UTF8.GetBytes('Placeholder two'))

    # Act
    $thrown = $null
    try {
        $null = $first, $legacy, $last | Update-FileToken -From 'Placeholder' -To 'Real'
    }
    catch {
        $thrown = $_
    }

    # Assert
    Assert-Equal -Expected 'RuntimeException,Update-FileToken' -Actual $thrown.FullyQualifiedErrorId `
        -Message 'A failing record in the pipeline raises the terminating error'
    Assert-Equal -Expected 'Real one' -Actual ([File]::ReadAllText($first)) `
        -Message 'the record before it is done'
    Assert-Equal -Expected 'Placeholder two' -Actual ([File]::ReadAllText($last)) `
        -Message 'and the pipeline stops, so the record after it is not touched'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $again = New-TestFile -Directory $sandbox -Name 'again.txt' -Byte ([Encoding]::UTF8.GetBytes('Placeholder three'))

    # Act - the same pipeline with the failure hidden: the failing record still stops it
    $output = @()
    try {
        $output = @($legacy, $again | Update-FileToken -From 'Placeholder' -To 'Real' -ErrorAction SilentlyContinue)
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected 0 -Actual $output.Count `
        -Message 'Under -ErrorAction SilentlyContinue a failing record still ends the pipeline'
    Assert-Equal -Expected 'Placeholder three' -Actual ([File]::ReadAllText($again)) `
        -Message 'so the record after it is not touched'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a blank path
    Assert-Throws -ScriptBlock { Update-FileToken -Path '  ' -From 'Placeholder' -To 'Real' } `
        -MessageLike 'The path is blank*' `
        -Message 'A blank path is refused as blank, not taken to mean the current folder'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
