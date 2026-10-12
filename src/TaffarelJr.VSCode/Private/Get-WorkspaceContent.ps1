using namespace System.Collections.Generic

function Get-WorkspaceContent {
    <#
    .SYNOPSIS
        Builds the whole .code-workspace, line by line.
    .DESCRIPTION
        Not exported. JSONC, not JSON: the comments are for the next
        reader, which is why this is assembled as text rather than
        through ConvertTo-Json. Sections with nothing in them are left
        out, and a comma follows every section but the last.
    .PARAMETER Directory
        The folder the workspace file will live in.
    .PARAMETER Folder
        Normalized folders, as ConvertTo-WorkspaceFolderSpec returns them.
    .PARAMETER Settings
        Explicit settings, keyed by setting name.
    .PARAMETER Extension
        Recommended extension ids.
    .PARAMETER Comment
        Lines written as comments at the top of the file.
    .PARAMETER MirrorFolderPath
        A folder whose .vscode/settings.json is copied into the settings.
    .OUTPUTS
        The file's lines, always an array.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Directory,

        [Parameter(Mandatory)]
        [object[]]$Folder,

        [System.Collections.IDictionary]$Settings,

        [string[]]$Extension,

        [string[]]$Comment,

        [string]$MirrorFolderPath
    )

    $sections = [List[string[]]]::new()
    $sections.Add((Get-WorkspaceFolderBlock -Directory $Directory -Folder $Folder))

    $settingBlock = Get-WorkspaceSettingBlock -Settings $Settings -MirrorFolderPath $MirrorFolderPath
    if ($settingBlock.Count -gt 0) {
        $sections.Add($settingBlock)
    }

    $extensionBlock = Get-WorkspaceExtensionBlock -Extension $Extension
    if ($extensionBlock.Count -gt 0) {
        $sections.Add($extensionBlock)
    }

    $lines = [List[string]]::new()
    $lines.Add('{')
    foreach ($note in $Comment) {
        $lines.Add("  // $note")
    }

    for ($i = 0; $i -lt $sections.Count; $i++) {
        $block = $sections[$i]
        for ($j = 0; $j -lt $block.Count; $j++) {
            $isLastOfSection = $j -eq $block.Count - 1
            $isLastSection = $i -eq $sections.Count - 1
            $comma = if ($isLastOfSection -and -not $isLastSection) { ',' } else { '' }
            $lines.Add($block[$j] + $comma)
        }
    }

    $lines.Add('}')
    return , $lines.ToArray()
}
