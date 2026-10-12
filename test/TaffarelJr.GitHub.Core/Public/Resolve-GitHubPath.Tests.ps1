#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubCoreTestHelper.ps1')

$work = New-CoreTestFolder
try {
    $here = Join-Path $work 'here'
    $there = Join-Path $work 'there'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a relative path, with PowerShell and the process in different folders
    $relative = Use-SplitLocation -Location $here -ProcessDirectory $there -ScriptBlock {
        Resolve-GitHubPath -Path (Join-Path 'out' 'file.txt')
    }

    # Assert
    Assert-Equal -Expected (Join-Path $here 'out' 'file.txt') -Actual $relative `
        -Message 'A relative path is taken from PowerShell''s location, not the process''s, and need not exist'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a path under the home folder, and one on a PowerShell drive
    $underHome = Resolve-GitHubPath -Path '~/x.txt'
    New-PSDrive -Name 'GhCoreTest' -PSProvider FileSystem -Root $there -Scope Global | Out-Null
    try {
        $onDrive = Resolve-GitHubPath -Path 'GhCoreTest:/y.txt'
    }
    finally {
        Remove-PSDrive -Name 'GhCoreTest' -Scope Global
    }

    # Assert
    Assert-Equal -Expected (Join-Path $HOME 'x.txt') -Actual $underHome `
        -Message '~ is the home folder, which gh would not expand'
    Assert-Equal -Expected (Join-Path $there 'y.txt') -Actual $onDrive `
        -Message 'A drive is the folder it stands for, which gh has never heard of'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a name holding wildcard characters
    $literal = Resolve-GitHubPath -Path (Join-Path $here 'a[1]*.txt')

    # Assert
    Assert-Equal -Expected (Join-Path $here 'a[1]*.txt') -Actual $literal `
        -Message 'A wildcard character is part of the name, not a pattern'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert - paths that are not on the file system
    Assert-Throws -ScriptBlock {
        Resolve-GitHubPath -Path 'Env:\PATH'
    } -MessageLike "*'Env:\PATH' is not a file system path (it is on the Environment provider)*" `
        -Message 'A path on another provider throws'
    Assert-Throws -ScriptBlock {
        Use-SplitLocation -Location 'Env:\' -ProcessDirectory $there -ScriptBlock {
            Resolve-GitHubPath -Path 'x.txt'
        }
    } -MessageLike "*'x.txt' is not a file system path*" `
        -Message 'and so does a relative path while PowerShell is somewhere other than the file system'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert - a drive PowerShell does not have, with and without a credential
    $unreadable = "'NoSuchDrive:\x.txt' is not a path PowerShell can read, so gh cannot use it:"
    Assert-Throws -ScriptBlock {
        Resolve-GitHubPath -Path 'NoSuchDrive:\x.txt'
    } -MessageLike ([WildcardPattern]::Escape($unreadable) + " *'NoSuchDrive'*") `
        -Message 'A drive PowerShell does not have throws the path, then its own reason, not the call that failed'
    $hiddenPath = [WildcardPattern]::Escape("'***@github.com/o/r' is not a path PowerShell can read, so gh cannot use it.")
    Assert-Throws -ScriptBlock {
        Resolve-GitHubPath -Path 'SENTINEL:x-oauth-basic@github.com/o/r'
    } -MessageLike $hiddenPath `
        -Message 'and one that holds a credential shows the path hidden, with no reason, which would repeat the drive name'
}
finally {
    Remove-CoreTestFolder -Path $work
}

exit (Complete-TestRun)
