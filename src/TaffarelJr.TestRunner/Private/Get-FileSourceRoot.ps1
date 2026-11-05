using namespace System.IO

function Get-FileSourceRoot {
    <#
    .SYNOPSIS
        Returns the source folders a test file's coverage is measured over:
        the one its display name starts with, or all of them when none is.
    .DESCRIPTION
        A run over every module would otherwise instrument every module's
        source for every file, which costs about as much as the file itself.
        The test tree mirrors the source tree, so the first segment of a
        display name is the source folder to measure.

        A root whose own name is that segment is taken first, as a run over
        one or several modules lists the module folders themselves; failing
        that, the first root holding a folder of that name gives it. A name
        with no slash, or a first segment no root matches, leaves the roots
        as they were given.
    .PARAMETER Name
        The test file's display name, with forward slashes between segments.
    .PARAMETER SourceRoot
        The source roots of the run.
    .OUTPUTS
        The folders, one at a time.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string[]]$SourceRoot
    )

    $slash = $Name.IndexOf('/')
    if ($slash -lt 1) {
        return $SourceRoot
    }

    $folder = $Name.Substring(0, $slash)
    foreach ($root in $SourceRoot) {
        $leaf = [Path]::GetFileName([Path]::TrimEndingDirectorySeparator($root))
        if ($leaf -eq $folder) {
            return $root
        }
    }

    foreach ($root in $SourceRoot) {
        $candidate = Join-Path -Path $root -ChildPath $folder
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            return $candidate
        }
    }

    return $SourceRoot
}
