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
    # Arrange - a parent folder that is not there
    $missing = Join-Path $sandbox 'nope' 'f.txt'
    $prefix = [WildcardPattern]::Escape("Cannot write '$missing': ")

    # Act / Assert
    Assert-Throws -ScriptBlock { Write-TextFile -Path $missing -Content 'x' } `
        -MessageLike "$prefix*Could not find a part of the path*" `
        -Message 'A missing parent folder says it cannot write the file, and why'
    Assert-That -Condition (-not (Test-Path -LiteralPath (Join-Path $sandbox 'nope'))) `
        -Message 'and creates no folder'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file another program holds open
    $locked = Join-Path $sandbox 'locked.txt'
    [File]::WriteAllText($locked, 'old')
    $hold = Lock-TestFile -Path $locked

    # Act / Assert
    try {
        Assert-Throws `
            -ScriptBlock {
                Write-TextFile -Path $locked -Content 'x' -Encoding ([UTF8Encoding]::new($false))
            } `
            -MessageLike ([WildcardPattern]::Escape("Cannot write '$locked': ") + '*being used by another process*') `
            -Message 'A file held open by another program says it cannot write the file, and why'
    }
    finally {
        $hold.Dispose()
    }

    Assert-Equal -Expected 'old' -Actual ([File]::ReadAllText($locked)) -Message 'and is left as it was'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a read-only file
    $readOnly = Join-Path $sandbox 'readonly.txt'
    [File]::WriteAllText($readOnly, 'old')
    (Get-Item -LiteralPath $readOnly).IsReadOnly = $true

    # Act / Assert
    Assert-Throws -ScriptBlock { Write-TextFile -Path $readOnly -Content 'x' } `
        -MessageLike ([WildcardPattern]::Escape("Cannot write '$readOnly': ") + '*denied*') `
        -Message 'A read-only file says it cannot write the file, and why'
    Assert-Equal -Expected 'old' -Actual ([File]::ReadAllText($readOnly)) -Message 'and is left as it was'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a folder that has to be made, but a file is in the way
    $blocker = Join-Path $sandbox 'blocker'
    [File]::WriteAllText($blocker, 'a file')
    $beneath = Join-Path $blocker 'sub' 'f.txt'

    # Act / Assert
    Assert-Throws -ScriptBlock { Write-TextFile -Path $beneath -Content 'x' -CreateDirectory } `
        -MessageLike ([WildcardPattern]::Escape("Cannot write '$beneath': ") + '*') `
        -Message '-CreateDirectory cannot make a folder where a file is in the way, and says it cannot write the file'
    Assert-Equal -Expected 'a file' -Actual ([File]::ReadAllText($blocker)) -Message 'and leaves that file as it was'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a blank path
    Assert-Throws -ScriptBlock { Write-TextFile -Path '  ' -Content 'x' } `
        -MessageLike 'The path is blank*' `
        -Message 'A blank path is refused as blank, not taken to mean the current folder'
    Assert-Throws -ScriptBlock { Write-TextFile -Path (Join-Path $sandbox 'new.txt') -Content 'x' -LikeFilePath ' ' } `
        -MessageLike 'The path is blank*' `
        -Message 'and so is a blank -LikeFilePath'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
