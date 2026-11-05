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
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $command = Get-Command Write-TextFile
    $viaName = Join-Path $sandbox 'via-name.txt'
    $viaAlias = Join-Path $sandbox 'via-alias.txt'

    # Act
    Write-TextFile -Path $viaName -Line @('a', 'b') -Encoding ([UTF8Encoding]::new($false))
    Write-TextFile -Path $viaAlias -Lines @('a', 'b') -Encoding ([UTF8Encoding]::new($false))

    # Assert
    Assert-Equal -Expected @('Lines') -Actual @($command.Parameters['Line'].Aliases) `
        -Message 'The lines are -Line, which is also called -Lines'
    Assert-Equal -Expected ([File]::ReadAllBytes($viaName)) -Actual ([File]::ReadAllBytes($viaAlias)) `
        -Message 'A call that says -Lines writes what the call that says -Line writes'

    #───────────────────────────────────────────────────────────────────────────
    # Assert - the set a call binds when it names neither -Line nor -Content
    Assert-Equal -Expected 'Lines' -Actual $command.DefaultParameterSet `
        -Message 'The default parameter set is the lines, the way text is usually built up'
    Assert-Equal -Expected @('Content', 'Lines') -Actual @($command.ParameterSets.Name | Sort-Object) `
        -Message 'and the other set is the whole content'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $whole = Join-Path $sandbox 'whole.txt'

    # Act
    Write-TextFile -Path $whole -Content 'no line ending added'

    # Assert
    Assert-Equal -Expected 'no line ending added' -Actual ([File]::ReadAllText($whole)) `
        -Message 'A call that names -Content binds the Content set and writes the text exactly'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two folders that are not there yet
    $deep = Join-Path $sandbox 'a' 'b' 'deep.txt'

    # Act
    Write-TextFile -Path $deep -Content 'deep' -CreateDirectory

    # Assert
    Assert-Equal -Expected 'deep' -Actual ([File]::ReadAllText($deep)) `
        -Message '-CreateDirectory makes the missing folders and writes the file in them'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a folder that is already there
    $present = Join-Path $sandbox 'present.txt'

    # Act
    Write-TextFile -Path $present -Content 'present' -CreateDirectory

    # Assert
    Assert-Equal -Expected 'present' -Actual ([File]::ReadAllText($present)) `
        -Message '-CreateDirectory leaves nothing to make when the folder is there, and writes the file'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - PowerShell is in one folder and the process in another
    $here = Join-Path $sandbox 'here'
    $there = Join-Path $sandbox 'there'
    New-Item -ItemType Directory -Path $here, $there | Out-Null

    # Act
    Use-SplitLocation -Location $here -ProcessDirectory $there -ScriptBlock {
        Write-TextFile -Path './made/f.txt' -Content 'x' -CreateDirectory
    }

    # Assert
    Assert-Equal -Expected 'x' -Actual ([File]::ReadAllText((Join-Path $here 'made' 'f.txt'))) `
        -Message 'A relative path makes its folders where PowerShell is'
    Assert-That -Condition (-not (Test-Path -LiteralPath (Join-Path $there 'made'))) `
        -Message 'not where the process is'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
