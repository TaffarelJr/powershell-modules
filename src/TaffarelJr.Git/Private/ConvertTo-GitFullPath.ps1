using namespace System.IO

function ConvertTo-GitFullPath {
    <#
    .SYNOPSIS
        Returns the full path a path given to this module names, for a
        -WhatIf or -Confirm message to show.
    .DESCRIPTION
        Read the way ConvertTo-GitPathspec reads it: a bare relative path,
        such as 'src/x.txt', is relative to the repository root; one that
        starts with '.' or '..' is relative to the folder git runs in; an
        absolute path is used as it is. Written with the platform's own
        separators, with '.' and '..' segments resolved.
    .PARAMETER Path
        The path to convert.
    .PARAMETER Root
        The repository root, as Get-GitRepoLocation returns it.
    .PARAMETER RepoPath
        The folder git runs in. Omit it for PowerShell's current location.
    .OUTPUTS
        The full path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Root,

        [string]$RepoPath
    )

    $full = Resolve-GitPath -Path $Path -RepoPath $RepoPath
    if (-not $full) {
        $full = [Path]::Combine($Root, ($Path -replace '\\', '/'))
    }

    return [Path]::GetFullPath($full)
}
