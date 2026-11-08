using namespace System.IO

function Get-SharedFolder {
    <#
    .SYNOPSIS
        Returns the deepest existing folder that holds every given path,
        or nothing when no folder holds them all.
    .DESCRIPTION
        A path that is itself an existing folder can be the answer; one that
        does not exist yet is held by its nearest existing parent. Paths on
        different drives share no folder.
    .PARAMETER Path
        Absolute paths.
    .OUTPUTS
        The folder's path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string[]]$Path
    )

    $folder = $Path[0]
    $parent = '..' + [Path]::DirectorySeparatorChar
    while ($folder) {
        $holdsAll = Test-Path -LiteralPath $folder -PathType Container
        foreach ($entry in $Path) {
            $relative = [Path]::GetRelativePath($folder, $entry)
            $climbs = $relative -eq '..' -or $relative.StartsWith($parent, [StringComparison]::Ordinal)
            if ($climbs -or [Path]::IsPathRooted($relative)) {
                $holdsAll = $false
            }
        }

        if ($holdsAll) {
            return $folder
        }

        $folder = Split-Path -Path $folder -Parent
    }
}
