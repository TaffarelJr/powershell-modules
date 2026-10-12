#Requires -Version 7.0
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/ConvertTo-WorkspaceFolderSpec.ps1')

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
$folder = Join-Path $root 'some-folder'
New-Item -ItemType Directory -Path $folder | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act
    $spec = ConvertTo-WorkspaceFolderSpec -Folder 'C:\repos\app'

    # Assert
    Assert-Equal -Expected 'C:\repos\app' -Actual $spec.Path -Message 'A bare string is the path'
    Assert-That -Condition ($null -eq $spec.Name) -Message 'A bare string has no name'
    Assert-That -Condition ($null -eq $spec.Comment) -Message 'A bare string has no comment'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $spec = ConvertTo-WorkspaceFolderSpec -Folder @{ Path = 'p'; Name = 'n'; Comment = 'c' }

    # Assert
    Assert-Equal -Expected 'p' -Actual $spec.Path -Message 'A dictionary''s Path is the path'
    Assert-Equal -Expected 'n' -Actual $spec.Name -Message 'A dictionary''s Name is the name'
    Assert-Equal -Expected 'c' -Actual $spec.Comment -Message 'A dictionary''s Comment is the comment'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $spec = ConvertTo-WorkspaceFolderSpec -Folder ([ordered]@{ Path = 'p' })

    # Assert
    Assert-Equal -Expected 'p' -Actual $spec.Path -Message 'An ordered dictionary works the same'
    Assert-That -Condition ($null -eq $spec.Name) -Message 'A field the dictionary leaves out is $null'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $spec = ConvertTo-WorkspaceFolderSpec -Folder ([PSCustomObject]@{ Path = 'p'; Name = 'n' })

    # Assert
    Assert-Equal -Expected 'p' -Actual $spec.Path -Message 'An object''s Path property is the path'
    Assert-Equal -Expected 'n' -Actual $spec.Name -Message 'An object''s Name property is the name'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $spec = ConvertTo-WorkspaceFolderSpec -Folder (Get-Item -LiteralPath $folder)

    # Assert
    Assert-Equal -Expected $folder -Actual $spec.Path -Message 'A DirectoryInfo has no Path, so its FullName is the path'
    Assert-Equal -Expected 'some-folder' -Actual $spec.Name -Message 'A DirectoryInfo''s own name is the name'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $spec = ConvertTo-WorkspaceFolderSpec -Folder ([PSCustomObject]@{ Path = 'chosen'; FullName = 'ignored' })

    # Assert
    Assert-Equal -Expected 'chosen' -Actual $spec.Path -Message 'Path wins over FullName when both are present'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { ConvertTo-WorkspaceFolderSpec -Folder @{ Name = 'no path' } } -Message 'A dictionary with no Path is refused'
    Assert-Throws -ScriptBlock { ConvertTo-WorkspaceFolderSpec -Folder ([PSCustomObject]@{ Other = 1 }) } -Message 'An object with neither Path nor FullName is refused'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
