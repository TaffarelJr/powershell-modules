using namespace System.Collections.Generic
using namespace System.IO

function Get-FolderSettingsBody {
    <#
    .SYNOPSIS
        Returns a folder's .vscode/settings.json body, re-indented for a
        .code-workspace 'settings' block.
    .DESCRIPTION
        Not exported. VS Code ignores window-scoped settings coming from
        folder settings while a multi-root workspace is open, so they have
        to be restated in the workspace file. Resource-scoped ones still
        resolve from the folder that defines them, which outranks this
        copy, so mirroring the whole file is safe and avoids hard-coding
        which keys are window-scoped.

        Spliced as text, not parsed, so key order and comments inside the
        object survive.
    .PARAMETER FolderPath
        The folder whose .vscode/settings.json is read.
    .OUTPUTS
        The body's lines, always an array - empty when the folder has no
        settings file or the file holds no JSON object.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FolderPath
    )

    $path = Join-Path $FolderPath '.vscode' 'settings.json'
    if (-not (Test-Path -LiteralPath $path)) {
        return , @()
    }

    # Taken between the outermost braces rather than assuming the file starts
    # with one: settings.json is JSONC, so a leading or trailing // note is
    # legal and must not read as 'not an object'.
    $text = [File]::ReadAllText($path).Trim()
    $open = $text.IndexOf('{')
    $close = $text.LastIndexOf('}')
    if ($open -lt 0 -or $close -le $open) {
        Write-Warning "No JSON object found, so not mirrored: $path"
        return , @()
    }

    $body = $text.Substring($open + 1, $close - $open - 1)
    $lines = [List[string]]::new()
    foreach ($line in ($body -split '\r?\n')) {
        if ($line.Trim()) {
            $lines.Add($line)
        }
    }

    if ($lines.Count -eq 0) {
        return , @()
    }

    # Whitespace, not spaces: a tab-indented file would otherwise measure as
    # zero and keep its tabs on top of the shift applied below.
    $indents = foreach ($line in $lines) {
        $line.Length - $line.TrimStart(' ', "`t").Length
    }

    $strip = [int]($indents | Measure-Object -Minimum).Minimum

    # Shifted one level deeper than the source, which sat at the top of its
    # own object - the workspace block it lands in is one level down.
    $shifted = foreach ($line in $lines) {
        '    ' + $line.Substring($strip)
    }

    return , @($shifted)
}
