using namespace System.Collections.Generic

function Get-WorkspaceFolderBlock {
    <#
    .SYNOPSIS
        Builds the workspace 'folders' block, one entry per folder.
    .DESCRIPTION
        Not exported. Each path is made relative to the workspace file's
        own folder, forward slashes only, since that is what VS Code
        resolves it against. The first folder is the primary one - tooling
        that is not multi-root aware only ever sees folders[0] - so order
        is the caller's to choose and is kept.
    .PARAMETER Directory
        The folder the workspace file will live in.
    .PARAMETER Folder
        Normalized folders, as ConvertTo-WorkspaceFolderSpec returns them.
        Each has to exist.
    .OUTPUTS
        The block's lines, always an array, with no trailing comma.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Directory,

        [Parameter(Mandatory)]
        [object[]]$Folder
    )

    $lines = [List[string]]::new()
    $lines.Add('  "folders": [')
    for ($i = 0; $i -lt $Folder.Count; $i++) {
        $spec = $Folder[$i]
        if ($spec.Comment) {
            foreach ($note in ($spec.Comment -split '\r?\n')) {
                $lines.Add("    // $note")
            }
        }

        $target = Get-NativePath -Path $spec.Path
        $relative = Get-RelativePosixPath -From $Directory -To $target
        $entry = '{ '
        if ($spec.Name) {
            $entry += '"name": ' + (ConvertTo-JsonLiteral -Value $spec.Name) + ', '
        }

        $entry += '"path": ' + (ConvertTo-JsonLiteral -Value $relative) + ' }'
        $comma = if ($i -lt $Folder.Count - 1) { ',' } else { '' }
        $lines.Add("    $entry$comma")
    }

    $lines.Add('  ]')
    return , $lines.ToArray()
}
