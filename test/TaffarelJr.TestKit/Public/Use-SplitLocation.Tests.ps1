#Requires -Version 7.4
using namespace System.IO

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Read by the script block or child process the test hands it to, by scope.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force

$one = (New-Item -ItemType Directory -Path (Join-Path ([Path]::GetTempPath()) "split-$([Guid]::NewGuid())")).FullName
$two = (New-Item -ItemType Directory -Path (Join-Path ([Path]::GetTempPath()) "split-$([Guid]::NewGuid())")).FullName
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $locationBefore = (Get-Location).ProviderPath
    $processBefore = [Environment]::CurrentDirectory

    # Act
    $inside = Use-SplitLocation -Location $one -ProcessDirectory $two -ScriptBlock {
        [PSCustomObject]@{
            Location         = (Get-Location).ProviderPath
            ProcessDirectory = [Environment]::CurrentDirectory
        }
    }

    # Assert
    Assert-Equal -Expected $one -Actual $inside.Location -Message 'PowerShell is in -Location while the block runs'
    Assert-Equal -Expected $two -Actual $inside.ProcessDirectory `
        -Message 'and the process is in -ProcessDirectory, a different folder'
    Assert-Equal -Expected $locationBefore -Actual (Get-Location).ProviderPath `
        -Message 'PowerShell''s location is put back afterwards'
    Assert-Equal -Expected $processBefore -Actual ([Environment]::CurrentDirectory) -Message 'and so is the process''s'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a relative path means different files to PowerShell and to .NET
    [File]::WriteAllText((Join-Path $one 'f.txt'), 'from PowerShell''s folder')
    [File]::WriteAllText((Join-Path $two 'f.txt'), 'from the process''s folder')
    $seen = Use-SplitLocation -Location $one -ProcessDirectory $two -ScriptBlock {
        [PSCustomObject]@{
            ByPowerShell = Get-Content -LiteralPath ./f.txt
            ByDotNet     = [File]::ReadAllText('./f.txt')
        }
    }

    # Assert
    Assert-Equal -Expected 'from PowerShell''s folder' -Actual $seen.ByPowerShell `
        -Message 'A PowerShell command reads the file in the location'
    Assert-Equal -Expected 'from the process''s folder' -Actual $seen.ByDotNet `
        -Message 'while .NET reads the one in the process''s directory - the split a test needs to see'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - what the block writes comes out, one item at a time
    $output = @(Use-SplitLocation -Location $one -ProcessDirectory $two -ScriptBlock { 'a'; 'b' })

    # Assert
    Assert-Equal -Expected @('a', 'b') -Actual $output -Message 'The block''s output is passed on'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - the block throws
    Assert-Throws `
        -ScriptBlock { Use-SplitLocation -Location $one -ProcessDirectory $two -ScriptBlock { throw 'boom' } } `
        -MessageLike 'boom' `
        -Message 'The block''s exception is not swallowed'

    # Assert
    Assert-Equal -Expected $locationBefore -Actual (Get-Location).ProviderPath `
        -Message 'PowerShell''s location is still put back'
    Assert-Equal -Expected $processBefore -Actual ([Environment]::CurrentDirectory) -Message 'and so is the process''s'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a block that pushes a location of its own and never pops it
    $stackBefore = (Get-Location -Stack).Count

    # Act
    Assert-Throws `
        -ScriptBlock {
            Use-SplitLocation -Location $one -ProcessDirectory $two -ScriptBlock {
                Push-Location -LiteralPath $two
                throw 'boom'
            }
        } `
        -MessageLike 'boom' `
        -Message 'A block that pushes and then throws still raises its own error'

    # Assert
    Assert-Equal -Expected $locationBefore -Actual (Get-Location).ProviderPath `
        -Message 'PowerShell''s location is put back whatever the block pushed'
    Assert-Equal -Expected ($stackBefore + 1) -Actual (Get-Location -Stack).Count `
        -Message 'and the default stack holds one more entry: the block''s own push, which is the block''s to pop'
    Assert-Equal -Expected $one -Actual (Get-Location -Stack).Peek().ProviderPath `
        -Message 'that entry is where the block pushed from, not the helper''s own entry'
    Pop-Location

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - folders that are not there
    $missing = Join-Path $one 'nope'
    Assert-Throws `
        -ScriptBlock { Use-SplitLocation -Location $missing -ProcessDirectory $two -ScriptBlock { 'x' } } `
        -MessageLike "*no such folder '*nope'*" `
        -Message 'A missing -Location is named'
    Assert-Throws `
        -ScriptBlock { Use-SplitLocation -Location $one -ProcessDirectory $missing -ScriptBlock { 'x' } } `
        -MessageLike "*no such folder '*nope'*" `
        -Message 'and so is a missing -ProcessDirectory'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a folder of another provider, which a process cannot be in
    Assert-Throws -ScriptBlock { Use-SplitLocation -Location $one -ProcessDirectory 'Env:\' -ScriptBlock { 'x' } } `
        -MessageLike "*not a file-system folder: 'Env:\'*" `
        -Message 'A -ProcessDirectory outside the file system is refused, naming it'
    Assert-Equal -Expected $processBefore -Actual ([Environment]::CurrentDirectory) `
        -Message 'and the process stays where it was'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $assigned = 'before'

    # Act
    Use-SplitLocation -Location $one -ProcessDirectory $two -ScriptBlock { $assigned = 'inside' }

    # Assert
    Assert-Equal -Expected 'inside' -Actual $assigned `
        -Message 'The block runs in the caller''s scope, so a variable it assigns is the caller''s'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - relative folders, given from PowerShell's current location (moved with Set-Location,
    # not the default stack, which the case above leaves one entry deeper on purpose)
    $parent = Split-Path -Parent $one
    $relativeOne = Split-Path -Leaf $one
    $relativeTwo = Split-Path -Leaf $two
    Set-Location -LiteralPath $parent
    try {
        # Act
        $relative = Use-SplitLocation -Location $relativeOne -ProcessDirectory $relativeTwo -ScriptBlock {
            [PSCustomObject]@{
                Location         = (Get-Location).ProviderPath
                ProcessDirectory = [Environment]::CurrentDirectory
            }
        }
    }
    finally {
        Set-Location -LiteralPath $locationBefore
    }

    # Assert
    Assert-Equal -Expected $one -Actual $relative.Location `
        -Message 'A relative -Location is resolved against PowerShell''s location'
    Assert-Equal -Expected $two -Actual $relative.ProcessDirectory `
        -Message 'and so is a relative -ProcessDirectory, not against the process''s own folder'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a block that moves PowerShell's location itself
    Use-SplitLocation -Location $one -ProcessDirectory $two -ScriptBlock { Set-Location -LiteralPath $two }

    # Assert
    Assert-Equal -Expected $locationBefore -Actual (Get-Location).ProviderPath `
        -Message 'A block that moves the location with Set-Location is put back where the caller was'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - one split inside another
    $nested = Use-SplitLocation -Location $one -ProcessDirectory $two -ScriptBlock {
        $inner = Use-SplitLocation -Location $two -ProcessDirectory $one -ScriptBlock {
            "$((Get-Location).ProviderPath)|$([Environment]::CurrentDirectory)"
        }
        "$inner / $((Get-Location).ProviderPath)|$([Environment]::CurrentDirectory)"
    }

    # Assert
    Assert-Equal -Expected "$two|$one / $one|$two" -Actual $nested `
        -Message 'A nested split restores the outer split, not the caller''s folders, when it ends'
    Assert-Equal -Expected $locationBefore -Actual (Get-Location).ProviderPath -Message 'and the caller''s location after both'
    Assert-Equal -Expected $processBefore -Actual ([Environment]::CurrentDirectory) -Message 'and the process''s'
}
finally {
    Remove-Item -LiteralPath $one, $two -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
