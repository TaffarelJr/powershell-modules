#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
$module = Get-Module TaffarelJr.FileText

if (-not $IsWindows) {
    exit (Skip-TestRun -Reason 'climbing above a drive root and the path length limit are Windows path rules')
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$root = [IO.Path]::GetPathRoot([IO.Path]::GetTempPath())
$aboveRoot = Join-Path $root '..\..\nope.txt'
$tooLong = Join-Path $root ('x' * 40000)

# Act
$climbing = { & $module { param($p) Resolve-TextFilePath -Path $p -MustExist } $aboveRoot }
$long = { & $module { param($p) Resolve-TextFilePath -Path $p -MustExist } $tooLong }

# Assert
Assert-Throws -ScriptBlock $climbing `
    -MessageLike "'$([WildcardPattern]::Escape($aboveRoot))' is not a usable file path: *outside*" `
    -Message 'A path that climbs above its drive root is refused, naming it and giving the reason'
Assert-Throws -ScriptBlock $long -MessageLike '*is not a usable file path: *too long*' `
    -Message 'and so is one too long for the file system'

exit (Complete-TestRun)
