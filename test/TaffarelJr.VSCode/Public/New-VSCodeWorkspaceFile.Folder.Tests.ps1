#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.VSCode/TaffarelJr.VSCode.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
$repo = Join-Path $root 'repo'
$lib = Join-Path $root 'lib'
New-Item -ItemType Directory -Path $repo, $lib | Out-Null
$ws = Join-Path $repo 'refused.code-workspace'
$blankWs = Join-Path $repo 'blank.code-workspace'
$twiceWs = Join-Path $repo 'twice.code-workspace'
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-VSCodeWorkspaceFile -Path $ws -Folder $null, $repo
    } -MessageLike '*A workspace folder is $null*' -Message 'A $null folder is refused with the module''s own message'
    Assert-Throws -ScriptBlock {
        New-VSCodeWorkspaceFile -Path $ws -Folder @()
    } -MessageLike '*No workspace folder was given.*' -Message 'An empty folder list is refused'
    Assert-Throws -ScriptBlock {
        @() | New-VSCodeWorkspaceFile -Path $ws
    } -MessageLike '*No workspace folder was given.*' -Message 'and so is an empty pipeline'
    Assert-Throws -ScriptBlock {
        New-VSCodeWorkspaceFile -Path $blankWs -Folder @{ Path = '   ' }
    } -MessageLike '*A workspace folder needs a Path.*' `
        -Message 'A dictionary whose Path is only spaces is refused, not taken for the current folder'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $separator = [Path]::DirectorySeparatorChar

    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-VSCodeWorkspaceFile -Path $twiceWs -Folder $lib, "$lib$separator"
    } -MessageLike '*The same workspace folder is given twice:*lib*' -Message 'One folder given twice is refused'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a -MirrorSettingsFrom that is missing, and one that is a file
    $missing = Join-Path $root 'not-there'
    $file = Join-Path $root 'settings.json'
    [File]::WriteAllText($file, '{ "a": 1 }')

    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-VSCodeWorkspaceFile -Path $ws -Folder $repo -MirrorSettingsFrom $missing
    } -MessageLike '*-MirrorSettingsFrom is not a folder:*not-there*' `
        -Message 'A -MirrorSettingsFrom that does not exist is refused, by name'
    Assert-Throws -ScriptBlock {
        New-VSCodeWorkspaceFile -Path $ws -Folder $repo -MirrorSettingsFrom $file
    } -MessageLike '*-MirrorSettingsFrom is not a folder:*settings.json*' `
        -Message 'A -MirrorSettingsFrom that is a file is refused, rather than adding nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $written = @(Get-ChildItem -LiteralPath $repo -Filter *.code-workspace)

    # Assert
    Assert-Equal -Expected 0 -Actual $written.Count -Message 'None of the refused calls wrote a file'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
