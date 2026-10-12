using namespace System.Collections.Generic

function Get-WorkspaceSettingBlock {
    <#
    .SYNOPSIS
        Builds the workspace 'settings' block, or nothing when there are no
        settings.
    .DESCRIPTION
        Not exported. Explicit settings come first, one per line, each value
        a single-line JSON literal. Settings mirrored from a folder follow
        them under a comment saying why they are there, since a reader of the
        workspace file would otherwise wonder.
    .PARAMETER Settings
        Explicit settings, keyed by setting name.
    .PARAMETER MirrorFolderPath
        A folder whose .vscode/settings.json is copied in as text.
    .OUTPUTS
        The block's lines, always an array - empty when there is nothing to
        write - with no trailing comma.
    #>
    param(
        [System.Collections.IDictionary]$Settings,

        [string]$MirrorFolderPath
    )

    $entries = [List[string]]::new()
    if ($Settings) {
        foreach ($key in $Settings.Keys) {
            $name = ConvertTo-JsonLiteral -Value "$key"
            $value = ConvertTo-JsonLiteral -Value $Settings[$key]
            $entries.Add("    ${name}: $value")
        }
    }

    $mirrored = [string[]]@()
    if ($MirrorFolderPath) {
        $mirrored = Get-FolderSettingsBody -FolderPath $MirrorFolderPath
    }

    if ($entries.Count -eq 0 -and $mirrored.Count -eq 0) {
        return , @()
    }

    $lines = [List[string]]::new()
    $lines.Add('  "settings": {')
    for ($i = 0; $i -lt $entries.Count; $i++) {
        $comma = if ($i -lt $entries.Count - 1 -or $mirrored.Count -gt 0) { ',' } else { '' }
        $lines.Add($entries[$i] + $comma)
    }

    if ($mirrored.Count -gt 0) {
        if ($entries.Count -gt 0) {
            $lines.Add('')
        }

        $lines.Add('    // Mirrored from .vscode/settings.json, because VS Code ignores')
        $lines.Add('    // window-scoped folder settings in a multi-root workspace.')
        $lines.AddRange([string[]]$mirrored)
    }

    $lines.Add('  }')
    return , $lines.ToArray()
}
