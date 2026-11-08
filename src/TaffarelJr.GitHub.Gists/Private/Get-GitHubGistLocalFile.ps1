using namespace System.IO

function Get-GitHubGistLocalFile {
    <#
    .SYNOPSIS
        Returns the full path of an existing local file under the name the
        file system has for it, not the one typed.
    .DESCRIPTION
        A gist file takes the name of the local file it comes from. On a
        case-insensitive file system 'notes.md' opens Notes.md, and Windows
        also opens it as 'Notes.md.' or 'Notes.md ', so the name is read
        from the folder's own entry: an exact match first, else the one
        that differs only in case. A typed name that matches no entry that
        way is refused rather than guessed at.
    .PARAMETER Path
        The full path of a file that exists.
    .PARAMETER Source
        How a message names the file: the value the caller typed, quoted,
        with the parameter it came from where that helps (-AddFile 'x'). It
        is shown as it is, so a caller hides any URL credential in it first.
    .OUTPUTS
        The full path, its last part as the file system names it.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Source
    )

    $folder = [Path]::GetDirectoryName($Path)
    $leaf = [Path]::GetFileName($Path)
    $names = @([Directory]::EnumerateFiles($folder) | ForEach-Object { [Path]::GetFileName($_) })
    if ($names -ccontains $leaf) {
        return $Path
    }

    $matched = @($names | Where-Object { $_ -eq $leaf })
    if ($matched.Count -ne 1) {
        throw "$Source is not a file."
    }

    return Join-Path $folder $matched[0]
}
