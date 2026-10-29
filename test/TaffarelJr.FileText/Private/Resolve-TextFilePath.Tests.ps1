#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'FileTextTestHelper.ps1')
$module = Get-Module TaffarelJr.FileText

$sandbox = New-FileTextSandbox
try {
    $file = Join-Path $sandbox 'f.txt'
    [File]::WriteAllText($file, 'x')

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act
    $absolute = & $module { param($p) Resolve-TextFilePath -Path $p } $file
    $missing = & $module { param($p) Resolve-TextFilePath -Path $p } (Join-Path $sandbox 'not-yet.txt')

    # Assert
    Assert-Equal -Expected $file -Actual $absolute -Message 'An absolute path to a file is returned as it is'
    Assert-Equal -Expected (Join-Path $sandbox 'not-yet.txt') -Actual $missing `
        -Message 'A file that does not exist yet resolves too, since a write may be about to create it'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - PowerShell is in one folder and the process in another
    $here = Join-Path $sandbox 'here'
    $there = Join-Path $sandbox 'there'
    New-Item -ItemType Directory -Path $here, $there | Out-Null

    # Act
    $relative = Use-SplitLocation -Location $here -ProcessDirectory $there -ScriptBlock {
        & $module { Resolve-TextFilePath -Path '.\f.txt' }
    }
    $parent = Use-SplitLocation -Location $here -ProcessDirectory $there -ScriptBlock {
        & $module { Resolve-TextFilePath -Path '..\f.txt' }
    }

    # Assert
    Assert-Equal -Expected (Join-Path $here 'f.txt') -Actual $relative `
        -Message 'A relative path is resolved against PowerShell''s location'
    Assert-Equal -Expected $file -Actual $parent -Message 'and a .. in it is followed'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a PowerShell drive over the folder
    $null = New-PSDrive -Name FileTextProbe -PSProvider FileSystem -Root $sandbox -Scope Global

    # Act
    try {
        $viaDrive = & $module { Resolve-TextFilePath -Path 'FileTextProbe:\f.txt' -MustExist }
    }
    finally {
        Remove-PSDrive -Name FileTextProbe -Scope Global
    }

    # Assert
    Assert-Equal -Expected $file -Actual $viaDrive `
        -Message 'A path on a PowerShell drive comes back as the real file system path'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a name with wildcard characters in it
    $brackets = Join-Path $sandbox 'a[1].txt'
    [File]::WriteAllText($brackets, 'x')

    # Act
    $literal = & $module { param($p) Resolve-TextFilePath -Path $p -MustExist } $brackets

    # Assert
    Assert-Equal -Expected $brackets -Actual $literal -Message 'Wildcard characters in a name are taken literally'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a file that is not there, and a folder
    Assert-Throws `
        -ScriptBlock { & $module { param($p) Resolve-TextFilePath -Path $p -MustExist } (Join-Path $sandbox 'nope.txt') } `
        -MessageLike "No such file: '*nope.txt'." `
        -Message '-MustExist names a missing file'
    Assert-Throws -ScriptBlock { & $module { param($p) Resolve-TextFilePath -Path $p } $sandbox } `
        -MessageLike '*is a folder, not a file.' `
        -Message 'A folder is refused, whether or not it has to exist'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - paths on drives of other providers
    Assert-Throws `
        -ScriptBlock { & $module { Resolve-TextFilePath -Path 'Env:FILETEXTPROBE' } } `
        -MessageLike "'Env:FILETEXTPROBE' is not a file system path; give the path of a file on disk." `
        -Message 'A path on the environment drive is refused, rather than coming back as a bare relative name'
    Assert-Throws `
        -ScriptBlock { & $module { Resolve-TextFilePath -Path 'Variable:probe' } } `
        -MessageLike "'Variable:probe' is not a file system path*" `
        -Message 'and so is one on the variable drive'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a drive and a provider that do not exist
    Assert-Throws `
        -ScriptBlock { & $module { Resolve-TextFilePath -Path 'NoSuchDrive:\f.txt' } } `
        -MessageLike "'NoSuchDrive:\f.txt' is not a path on any drive or provider here; give the path of a file on disk." `
        -Message 'A path on a drive that does not exist is refused, naming it'
    Assert-Throws `
        -ScriptBlock { & $module { Resolve-TextFilePath -Path 'NoSuchProvider::f.txt' } } `
        -MessageLike "'NoSuchProvider::f.txt' is not a path on any drive or provider here*" `
        -Message 'and so is one through a provider that does not exist'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $withNul = Join-Path $sandbox "a$([char]0)b.txt"

    # Act / Assert
    Assert-Throws `
        -ScriptBlock { & $module { param($p) Resolve-TextFilePath -Path $p -MustExist } $withNul } `
        -MessageLike '*is not a usable file path: *' `
        -Message 'A path holding a NUL character is refused with a message of its own, giving the reason'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a path of nothing but whitespace, which would resolve to the current folder
    Assert-Throws -ScriptBlock { & $module { Resolve-TextFilePath -Path '  ' } } `
        -MessageLike 'The path is blank; give the path of a file on disk.' `
        -Message 'A blank path is refused as blank, whether or not it has to exist'
    Assert-Throws -ScriptBlock { & $module { Resolve-TextFilePath -Path "`t" -MustExist } } `
        -MessageLike 'The path is blank; give the path of a file on disk.' `
        -Message 'and so is one that is only a tab'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
