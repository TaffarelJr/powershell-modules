using namespace System.IO

function Get-TestDisplayName {
    <#
    .SYNOPSIS
        Returns a test file's path relative to the test folder,
        without the suffix and with forward slashes,
        so two files of the same name in different folders still read apart.
    #>
    param(
        [Parameter(Mandatory)][string]$TestRoot,
        [Parameter(Mandatory)][string]$File
    )

    $relative = [Path]::GetRelativePath($TestRoot, $File)
    return ($relative -replace '\.Tests\.ps1$' -replace '\\', '/')
}
