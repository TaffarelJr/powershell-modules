using namespace System.Collections.Generic

function Get-WorkspaceExtensionBlock {
    <#
    .SYNOPSIS
        Builds the workspace 'extensions' block, or nothing when no
        extension is recommended.
    .DESCRIPTION
        Not exported. Extension ids are not case-sensitive, so an id given
        again in other casing is written once, as it was first given.
    .PARAMETER Extension
        Extension ids in publisher.name form.
    .OUTPUTS
        The block's lines, one at a time - none when there is nothing to
        write - with no trailing comma.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Extension
    )

    if (-not $Extension) {
        return
    }

    $unique = [List[string]]::new()
    foreach ($id in $Extension) {
        if ($unique -notcontains $id) {
            $unique.Add($id)
        }
    }

    $lines = [List[string]]::new()
    $lines.Add('  "extensions": {')
    $lines.Add('    "recommendations": [')
    for ($i = 0; $i -lt $unique.Count; $i++) {
        $literal = ConvertTo-JsonLiteral -Value $unique[$i]
        $comma = if ($i -lt $unique.Count - 1) { ',' } else { '' }
        $lines.Add("      $literal$comma")
    }

    $lines.Add('    ]')
    $lines.Add('  }')
    return $lines.ToArray()
}
