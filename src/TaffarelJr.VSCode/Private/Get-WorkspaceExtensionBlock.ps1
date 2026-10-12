using namespace System.Collections.Generic

function Get-WorkspaceExtensionBlock {
    <#
    .SYNOPSIS
        Builds the workspace 'extensions' block, or nothing when no
        extension is recommended.
    .DESCRIPTION
        Not exported.
    .PARAMETER Extension
        Extension ids in publisher.name form.
    .OUTPUTS
        The block's lines, always an array - empty when there is nothing to
        write - with no trailing comma.
    #>
    param(
        [string[]]$Extension
    )

    if (-not $Extension) {
        return , @()
    }

    $lines = [List[string]]::new()
    $lines.Add('  "extensions": {')
    $lines.Add('    "recommendations": [')
    for ($i = 0; $i -lt $Extension.Count; $i++) {
        $literal = ConvertTo-JsonLiteral -Value $Extension[$i]
        $comma = if ($i -lt $Extension.Count - 1) { ',' } else { '' }
        $lines.Add("      $literal$comma")
    }

    $lines.Add('    ]')
    $lines.Add('  }')
    return , $lines.ToArray()
}
