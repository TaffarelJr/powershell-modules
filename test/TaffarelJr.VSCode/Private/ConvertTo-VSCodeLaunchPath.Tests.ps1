#Requires -Version 7.4
using namespace System.Collections.Generic
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Get-DictionaryValue.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/ConvertTo-VSCodeLaunchPath.ps1')

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
$repo = Join-Path $root 'repo'
$file = Join-Path $repo 'a.txt'
New-Item -ItemType Directory -Path $repo | Out-Null
[File]::WriteAllText($file, '')
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Equal -Expected $repo -Actual (ConvertTo-VSCodeLaunchPath -InputObject $repo) `
        -Message 'An absolute path is returned as it is'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    Push-Location -LiteralPath $root
    try {
        $path = ConvertTo-VSCodeLaunchPath -InputObject 'repo'
    }
    finally {
        Pop-Location
    }

    # Assert
    Assert-Equal -Expected $repo -Actual $path -Message 'A relative path resolves against the current location'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - objects that carry their path
    $objects = @(
        @{ Value = (Resolve-Path -LiteralPath $repo); Expected = $repo; Message = 'A PathInfo gives its Path' }
        @{
            Value = (Get-Item -LiteralPath $file)
            Expected = $file
            Message = 'A FileInfo, which has no Path, gives its FullName'
        }
        @{
            Value = [PSCustomObject]@{ Path = $repo; FullName = $file }
            Expected = $repo
            Message = 'Path wins over FullName'
        }
        @{
            Value = [PSCustomObject]@{ Path = ''; FullName = $file }
            Expected = $file
            Message = 'An empty Path falls back to FullName'
        }
        @{ Value = @{ path = $repo }; Expected = $repo; Message = 'A dictionary gives its Path entry, in any casing' }
        @{ Value = @{ FULLNAME = $file }; Expected = $file; Message = 'or its FullName entry' }
    )

    # Act / Assert
    foreach ($case in $objects) {
        Assert-Equal -Expected $case.Expected -Actual (ConvertTo-VSCodeLaunchPath -InputObject $case.Value) `
            -Message $case.Message
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - dictionaries whose own lookup is case-sensitive, keyed in
    # lowercase
    $lowerPath = [Dictionary[string, object]]::new()
    $lowerPath['path'] = $repo
    $lowerFullName = [Dictionary[string, object]]::new()
    $lowerFullName['fullname'] = $file

    # Act
    $fromPath = ConvertTo-VSCodeLaunchPath -InputObject $lowerPath
    $fromFullName = ConvertTo-VSCodeLaunchPath -InputObject $lowerFullName

    # Assert
    Assert-Equal -Expected $repo -Actual $fromPath -Message 'A case-sensitive dictionary gives its lowercase path entry'
    Assert-Equal -Expected $file -Actual $fromFullName -Message 'and its lowercase fullname entry'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a dictionary keyed by numbers, which cannot hold a Path
    $numbered = [Dictionary[int, object]]::new()
    $numbered[1] = $repo

    # Act / Assert
    Assert-Throws -ScriptBlock {
        ConvertTo-VSCodeLaunchPath -InputObject $numbered
    } -MessageLike '*Cannot open a System.Collections.Generic.Dictionary*no Path or FullName property*' `
        -Message 'A dictionary keyed by numbers is refused with the module''s own message'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - things with no path in them
    $pathless = @(
        @{
            Value = [PSCustomObject]@{ Number = 7 }
            Type = 'System.Management.Automation.PSCustomObject'
            Message = 'An object with neither Path nor FullName is refused, not opened as its text'
        }
        @{
            Value = @{ Name = 'n' }
            Type = 'System.Collections.Hashtable'
            Message = 'A dictionary with neither entry is refused'
        }
        @{ Value = 42; Type = 'System.Int32'; Message = 'A number is refused' }
    )

    # Act / Assert
    foreach ($case in $pathless) {
        Assert-Throws -ScriptBlock {
            ConvertTo-VSCodeLaunchPath -InputObject $case.Value
        } -MessageLike "*Cannot open a $($case.Type) in VS Code: it has no Path or FullName property*" `
            -Message $case.Message
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - blank paths, which would otherwise mean the current folder
    $blank = @(
        @{ Value = ''; Message = 'An empty string is refused' }
        @{ Value = " `t "; Message = 'A string of only whitespace is refused' }
        @{ Value = [PSCustomObject]@{ Path = '   ' }; Message = 'An object whose Path is only whitespace is refused' }
    )

    # Act / Assert
    foreach ($case in $blank) {
        Assert-Throws -ScriptBlock {
            ConvertTo-VSCodeLaunchPath -InputObject $case.Value
        } -MessageLike '*-Path is empty or only whitespace*' -Message $case.Message
    }

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock {
        ConvertTo-VSCodeLaunchPath -InputObject 'Q9:\x'
    } -MessageLike "*Cannot open 'Q9:\x' in VS Code*Q9*" `
        -Message 'A drive that does not exist is refused with the module''s own message'
    Assert-Throws -ScriptBlock {
        ConvertTo-VSCodeLaunchPath -InputObject 'Env:\PATH'
    } -MessageLike '*file system paths only*Environment*Env:\PATH*' `
        -Message 'A path in another provider is refused, naming the provider'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
