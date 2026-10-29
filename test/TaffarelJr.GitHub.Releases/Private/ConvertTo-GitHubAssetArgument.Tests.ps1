#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$manifest = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Releases/TaffarelJr.GitHub.Releases.psd1'
$module = Import-Module $manifest -Force -PassThru
. (Join-Path $PSScriptRoot '..' 'GitHubReleasesTestHelper.ps1')

$convert = {
    param($LiteralPath)
    ConvertTo-GitHubAssetArgument -LiteralPath $LiteralPath -Name 'LiteralPath'
}

$folder = New-ReleaseTestFolder -File 'a[1].zip', 'C#/b.zip', 'C#/sub/c.zip', 'x#y.zip'
$elsewhere = New-ReleaseTestFolder
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file whose name gh would read as a wildcard pattern
    $file = Join-Path $folder 'a[1].zip'

    # Act
    $argument = & $module $convert $file

    # Assert
    Assert-Equal `
        -Expected "$file#" `
        -Actual $argument `
        -Message 'The full path gains a bare # on the end, so gh takes it literally'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a relative path, with PowerShell and the process in different folders
    $argument = Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        & $module $convert 'a[1].zip'
    }

    # Assert
    Assert-Equal `
        -Expected "$(Join-Path $folder 'a[1].zip')#" `
        -Actual $argument `
        -Message 'A relative path is resolved against PowerShell''s location'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a file in a folder whose name holds a #, from inside that folder
    $argument = Use-SplitLocation -Location (Join-Path $folder 'C#') -ProcessDirectory $elsewhere -ScriptBlock {
        & $module $convert (Join-Path $folder 'C#' 'sub' 'c.zip')
    }

    # Assert
    Assert-Equal `
        -Expected "$(Join-Path 'sub' 'c.zip')#" `
        -Actual $argument `
        -Message 'A # in the folder is avoided by the path relative to the current location'

    #───────────────────────────────────────────────────────────────────────────
    # Act - the same file from a location above that folder
    Push-Location -LiteralPath $folder

    # Assert
    try {
        Assert-Throws -ScriptBlock {
            & $module $convert (Join-Path 'C#' 'b.zip')
        } -MessageLike "-LiteralPath '*C#*b.zip' holds a '#'*" `
            -Message 'A # left in the relative path too is refused, naming the parameter and the file'
    }
    finally {
        Pop-Location
    }

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a # in the file name itself
    Assert-Throws -ScriptBlock {
        & $module $convert (Join-Path $folder 'x#y.zip')
    } -MessageLike "-LiteralPath '*x#y.zip' holds a '#'*rename or copy*" `
        -Message 'A # in the name cannot be avoided, so it is refused'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a path that names no file
    Assert-Throws -ScriptBlock {
        & $module $convert (Join-Path $folder 'C#')
    } -MessageLike "-LiteralPath '*C#' is not a file." -Message 'A folder is refused before gh sees it'
}
finally {
    Remove-Item -LiteralPath $folder, $elsewhere -Recurse -Force
}

exit (Complete-TestRun)
