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
    Set-Content -LiteralPath (Join-Path $here 'key.pub') -Value 'ssh-ed25519 AAAA fake'
    Set-Content -LiteralPath (Join-Path $there 'key.pub') -Value 'the wrong file'
    Set-Content -LiteralPath (Join-Path $here 'a[1].pub') -Value 'a name with brackets'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a relative path, with PowerShell and the process in different folders
    $found = Use-SplitLocation -Location $here -ProcessDirectory $there -ScriptBlock {
        Resolve-GitHubInputFile -Path 'key.pub'
    }

    # Assert
    Assert-Equal -Expected (Join-Path $here 'key.pub') -Actual $found `
        -Message 'A relative path is found from PowerShell''s location, and the full path returned'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a full path
    $full = Resolve-GitHubInputFile -Path (Join-Path $there 'key.pub') -Name 'KeyFile'

    # Assert
    Assert-Equal -Expected (Join-Path $there 'key.pub') -Actual $full `
        -Message 'A full path to a file is returned as it is'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a file whose name holds brackets, given relative to PowerShell's location
    $bracketed = Use-SplitLocation -Location $here -ProcessDirectory $there -ScriptBlock {
        Resolve-GitHubInputFile -Path 'a[1].pub'
    }

    # Assert
    Assert-Equal -Expected (Join-Path $here 'a[1].pub') -Actual $bracketed `
        -Message 'A name holding brackets is taken literally and resolves to that file'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - what is not a file gh can read
    $refused = @(
        @{
            Path = (Join-Path $here 'missing.pub')
            Like = "-KeyFile '*missing.pub' is not a file."
            Message = 'A missing file throws, naming the parameter'
        }
        @{ Path = $here; Like = "-KeyFile '*here' is not a file."; Message = 'and so does a folder' }
        @{
            Path = '-'
            Like = "-KeyFile '-' would make gh read standard input*"
            Message = 'A lone dash throws, since gh would wait on standard input'
        }
        @{ Path = ' - '; Like = "-KeyFile ' - ' would make gh read standard input*"; Message = 'however it is padded' }
        @{
            Path = (Join-Path $here 'k*.pub')
            Like = "-KeyFile '*k``*.pub' is not a file."
            Message = 'A path holding a wildcard is never expanded: with no file of that exact name it is just not a file'
        }
        @{
            Path = (Join-Path $here 'missing[1].pub')
            Like = "-KeyFile '*missing``[1``].pub' is not a file."
            Message = 'and so is a missing name holding brackets'
        }
        @{
            Path = 'Env:\PATH'
            Like = "*'Env:\PATH' is not a file system path*"
            Message = 'A path on another provider throws'
        }
    )

    # Assert
    foreach ($case in $refused) {
        Assert-Throws -ScriptBlock {
            Resolve-GitHubInputFile -Path $case.Path -Name 'KeyFile'
        } -MessageLike $case.Like -Message $case.Message
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert - the message without a parameter name, and a name given with its dash
    Assert-Throws -ScriptBlock {
        Resolve-GitHubInputFile -Path (Join-Path $here 'missing.pub')
    } -MessageLike "'*missing.pub' is not a file." -Message 'Without -Name the message starts at the path'
    Assert-Throws -ScriptBlock {
        Resolve-GitHubInputFile -Path '-'
    } -MessageLike "'-' would make gh read standard input: give the path of a file." `
        -Message 'and so does the lone dash''s'
    Assert-Throws -ScriptBlock {
        Resolve-GitHubInputFile -Path (Join-Path $here 'key.pub') -Name '-KeyFile'
    } -MessageLike "*'-KeyFile' is not a parameter name: give it without its dash." `
        -Message '-Name is the parameter''s name without its dash'
}
finally {
    Remove-CoreTestFolder -Path $work
}

exit (Complete-TestRun)
