using namespace System.IO

function Get-TestDisplayName {
    <#
    .SYNOPSIS
        Returns a test file's path relative to the test folder,
        without the suffix and with forward slashes,
        so two files of the same name in different folders still read apart.
    .DESCRIPTION
        Throws for a file that is not under the test folder: its name would
        climb out with '..', and the reports named after it would be written
        outside the folder meant to hold them.
    .PARAMETER TestRoot
        The folder every name is relative to.
    .PARAMETER File
        The test file's full path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TestRoot,

        [Parameter(Mandatory)]
        [string]$File
    )

    $relative = [Path]::GetRelativePath($TestRoot, $File)
    $parent = '..' + [Path]::DirectorySeparatorChar
    $climbs = $relative -eq '..' -or $relative.StartsWith($parent, [StringComparison]::Ordinal)
    if ($climbs -or [Path]::IsPathRooted($relative)) {
        throw "Test file '$File' is not under -TestRoot '$TestRoot'."
    }

    return ($relative -replace '\.Tests\.ps1$' -replace '\\', '/')
}
