#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - text with mixed line endings and characters beyond ASCII
$text = "first`r`nsecond`nthird é ✓"

# Act
$seen = Use-GitHubTextFile -Text $text -ScriptBlock {
    param($Path)
    [PSCustomObject]@{
        Path   = $Path
        Bytes  = [System.IO.File]::ReadAllBytes($Path)
        Rooted = [System.IO.Path]::IsPathRooted($Path)
    }
}

# Assert
Assert-Equal -Expected ([Convert]::ToHexString([System.Text.Encoding]::UTF8.GetBytes($text))) `
    -Actual ([Convert]::ToHexString($seen.Bytes)) `
    -Message 'The file holds the text exactly: UTF-8, no byte-order mark, no newline added, line endings untouched'
Assert-Equal -Expected $true -Actual $seen.Rooted -Message 'The block is given the file''s full path'
Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $seen.Path) -Message 'and the file is gone afterwards'

#───────────────────────────────────────────────────────────────────────────────
# Act - an empty text
$length = Use-GitHubTextFile -Text '' -ScriptBlock {
    param($Path)
    (Get-Item -LiteralPath $Path).Length
}

# Assert
Assert-Equal -Expected 0L -Actual $length -Message 'An empty text gives an empty file'

#───────────────────────────────────────────────────────────────────────────────
# Act - a block that writes several things
$lines = @(Use-GitHubTextFile -Text 'x' -ScriptBlock { 'one'; 'two' })

# Assert
Assert-Equal -Expected @('one', 'two') -Actual $lines `
    -Message 'Whatever the block writes is returned, one item at a time'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a block that throws
$kept = @{}

# Act / Assert
Assert-Throws -ScriptBlock {
    Use-GitHubTextFile -Text 'secret' -ScriptBlock {
        param($Path)
        $kept.Path = $Path
        throw 'boom'
    }
} -MessageLike '*boom*' -Message 'A throw from the block comes through'
Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $kept.Path) `
    -Message 'and the file is deleted all the same'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a fake gh, which records the content of a file it is given
$fake = New-FakeGitHubCli
try {
    # Act
    Use-GitHubTextFile -Text "Body`nwith lines" -ScriptBlock {
        param($Path)
        Invoke-GitHubCommand -Activity 'Commenting' -Argument @('issue', 'comment', '7', '--body-file', $Path)
    } | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected "Body`nwith lines" -Actual $call.Files[$call.Arguments[4]] `
        -Message 'gh reads the text from the file while it is called'
    Assert-Equal -Expected $false -Actual $call.StdInPiped -Message 'and nothing travels on standard input'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
