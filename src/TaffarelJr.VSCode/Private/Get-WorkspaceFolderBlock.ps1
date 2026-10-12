using namespace System.Collections.Generic
using namespace System.IO

function Get-WorkspaceFolderBlock {
    <#
    .SYNOPSIS
        Builds the workspace 'folders' block, one entry per folder.
    .DESCRIPTION
        Not exported. Each path is made relative to the workspace file's
        own folder, forward slashes only, since that is what VS Code
        resolves it against. The first folder is the primary one - tooling
        that is not multi-root aware only ever sees folders[0] - so order
        is the caller's to choose and is kept. A trailing separator is
        dropped, and a folder given twice is refused - compared ignoring
        case on Windows, whose file system does.
    .PARAMETER Directory
        The folder the workspace file will live in.
    .PARAMETER Folder
        Normalized folders, as ConvertTo-WorkspaceFolderSpec returns them.
        Each has to exist.
    .OUTPUTS
        The block's lines, one at a time, with no trailing comma.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Directory,

        [Parameter(Mandatory)]
        [object[]]$Folder
    )

    $comparer = [StringComparer]::Ordinal
    if ($IsWindows) {
        $comparer = [StringComparer]::OrdinalIgnoreCase
    }

    $seen = [HashSet[string]]::new($comparer)
    $lines = [List[string]]::new()
    $lines.Add('  "folders": [')
    for ($i = 0; $i -lt $Folder.Count; $i++) {
        $spec = $Folder[$i]
        if ($spec.Comment) {
            foreach ($note in ($spec.Comment -split '\r\n|\r|\n')) {
                $lines.Add("    // $note")
            }
        }

        if (-not (Test-Path -LiteralPath $spec.Path)) {
            throw "A workspace folder does not exist: $($spec.Path)"
        }

        $target = [Path]::TrimEndingDirectorySeparator((Get-NativePath -Path $spec.Path))
        if (-not (Test-Path -LiteralPath $target -PathType Container)) {
            throw "A workspace folder must be a folder, and this is not: $target"
        }

        if (-not $seen.Add($target)) {
            throw "The same workspace folder is given twice: $target"
        }

        $relative = Get-RelativePosixPath -From $Directory -To $target
        $entry = '{ '
        if (-not [string]::IsNullOrEmpty([string]$spec.Name)) {
            $entry += '"name": ' + (ConvertTo-JsonLiteral -Value ([string]$spec.Name)) + ', '
        }

        $entry += '"path": ' + (ConvertTo-JsonLiteral -Value $relative) + ' }'
        $comma = if ($i -lt $Folder.Count - 1) { ',' } else { '' }
        $lines.Add("    $entry$comma")
    }

    $lines.Add('  ]')
    return $lines.ToArray()
}
