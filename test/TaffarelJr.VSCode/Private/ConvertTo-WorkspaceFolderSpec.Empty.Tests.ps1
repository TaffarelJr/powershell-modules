#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Get-DictionaryValue.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/ConvertTo-WorkspaceFolderSpec.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - folders that name nowhere
$empty = @(
    @{ Folder = ''; Message = 'An empty string is refused, not taken for the current folder' }
    @{ Folder = '   '; Message = 'as is one of spaces' }
    @{ Folder = @{ Path = ''; Name = 'n' }; Message = 'A dictionary with an empty Path is refused' }
    @{ Folder = @{ Path = '   ' }; Message = 'as is a dictionary whose Path is only spaces' }
    @{ Folder = [PSCustomObject]@{ Path = ' ' }; Message = 'and an object whose Path is only a space' }
    @{ Folder = [PSCustomObject]@{ Name = 'n' }; Message = 'and an object with no Path or FullName' }
)

# Act / Assert
foreach ($case in $empty) {
    Assert-Throws -ScriptBlock {
        ConvertTo-WorkspaceFolderSpec -Folder $case.Folder
    } -MessageLike '*A workspace folder needs a Path.*' -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock {
    ConvertTo-WorkspaceFolderSpec -Folder $null
} -MessageLike '*A workspace folder is $null*' -Message 'A $null folder is refused with the module''s own message'

exit (Complete-TestRun)
