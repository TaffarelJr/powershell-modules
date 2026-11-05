using namespace System.IO

function Get-RelativePosixPath {
    <#
    .SYNOPSIS
        Returns the path from one location to another, forward slashes
        only.
    .DESCRIPTION
        Not exported. A workspace folder entry needs exactly this, and a
        subtraction of string lengths is not it.
    .PARAMETER From
        The folder the result is relative to.
    .PARAMETER To
        The location the result points at.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$From,

        [Parameter(Mandatory)]
        [string]$To
    )

    return [Path]::GetRelativePath($From, $To) -replace '\\', '/'
}
