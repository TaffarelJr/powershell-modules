using namespace System.Collections
using namespace System.Collections.Generic

function Get-FolderSettingsBody {
    <#
    .SYNOPSIS
        Returns the body of a folder's .vscode/settings.json, re-indented for
        the settings block of a workspace file, with its top-level keys.
    .DESCRIPTION
        Not exported. VS Code ignores window-scoped settings coming from
        folder settings while a multi-root workspace is open, so they have
        to be restated in the workspace file. The whole file is copied, which
        avoids hard-coding which keys are window-scoped; the price is that
        workspace settings apply to every folder in the workspace, so the
        rest of the copy reaches the other folders too, wherever they do not
        set the same key themselves.

        The file is parsed first, so one that PowerShell's JSON reader cannot
        parse, or that holds something other than an object, is refused
        rather than breaking the workspace file it would be spliced into.
        Looseness the reader accepts but VS Code itself flags, such as
        unquoted keys or single-quoted strings, is copied as written. It is
        then spliced as text, not re-serialized, so key order and comments
        inside the object survive. The object is found by walking the text
        past strings and comments, so a brace in a note before or after it,
        or inside a string, is not taken for its edge. A file that is not
        valid UTF-8 text is refused, not read with replacement characters.
    .PARAMETER FolderPath
        The folder whose .vscode/settings.json is read.
    .OUTPUTS
        An object with Keys (the top-level setting names, in file order) and
        Lines (the body, one line each) - nothing when the folder has no
        settings file, or the file holds only whitespace, notes, or an empty
        object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FolderPath
    )

    $path = Join-Path -Path $FolderPath -ChildPath '.vscode' -AdditionalChildPath 'settings.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return
    }

    try {
        $text = (Read-TextFile -Path $path).Content
    }
    catch {
        throw "The settings file cannot be read, so it cannot be mirrored: $path ($($_.Exception.Message))"
    }

    try {
        $parsed = ConvertFrom-Json -InputObject $text -AsHashtable -NoEnumerate
    }
    catch {
        throw "The settings file is not valid JSON, so it cannot be mirrored: $path ($($_.Exception.Message))"
    }

    # VS Code reads a file of only whitespace or notes as no settings at all.
    if ($null -eq $parsed) {
        return
    }

    if ($parsed -isnot [IDictionary]) {
        throw "The settings file does not hold a JSON object, so it cannot be mirrored: $path"
    }

    # Single quotes open a string and a lone CR ends a note, because the
    # parser that has just accepted the text reads them that way.
    $open = -1
    $close = -1
    $depth = 0
    $i = 0
    while ($i -lt $text.Length -and $close -lt 0) {
        $char = $text[$i]
        $next = if ($i + 1 -lt $text.Length) { $text[$i + 1] } else { [char]0 }
        if ($char -eq '"' -or $char -eq "'") {
            $i++
            while ($i -lt $text.Length -and $text[$i] -ne $char) {
                if ($text[$i] -eq '\') {
                    $i++
                }

                $i++
            }
        }
        elseif ($char -eq '/' -and $next -eq '/') {
            while ($i -lt $text.Length -and $text[$i] -ne "`n" -and $text[$i] -ne "`r") {
                $i++
            }
        }
        elseif ($char -eq '/' -and $next -eq '*') {
            $end = $text.IndexOf('*/', $i + 2, [StringComparison]::Ordinal)
            $i = if ($end -lt 0) { $text.Length } else { $end + 1 }
        }
        elseif ($char -eq '{') {
            if ($depth -eq 0 -and $open -lt 0) {
                $open = $i
            }

            $depth++
        }
        elseif ($char -eq '}') {
            $depth--
            if ($depth -eq 0) {
                $close = $i
            }
        }

        $i++
    }

    if ($close -lt 0) {
        throw "The settings file's object could not be located for mirroring: $path"
    }

    $parts = $text.Substring($open + 1, $close - $open - 1) -split '\r\n|\r|\n'

    # Text on the opening brace's own line has no indent of its own to
    # measure, so it is placed by itself.
    $first = $parts[0].Trim()
    $rest = [List[string]]::new()
    for ($j = 1; $j -lt $parts.Count; $j++) {
        $line = $parts[$j].TrimEnd()
        if ($line) {
            $rest.Add($line)
        }
    }

    $lines = [List[string]]::new()
    if ($first) {
        $lines.Add('    ' + $first)
    }

    if ($rest.Count -gt 0) {
        # Whitespace, not spaces: a tab-indented file would otherwise measure
        # as zero and keep its tabs on top of the shift applied below.
        $indents = foreach ($line in $rest) {
            $line.Length - $line.TrimStart(' ', "`t").Length
        }

        $strip = [int]($indents | Measure-Object -Minimum).Minimum

        # Shifted one level deeper than the source, which sat at the top of
        # its own object - the workspace block it lands in is one level down.
        foreach ($line in $rest) {
            $lines.Add('    ' + $line.Substring($strip))
        }
    }

    if ($lines.Count -eq 0) {
        return
    }

    return [PSCustomObject]@{
        Keys  = [string[]]@($parsed.PSBase.Keys)
        Lines = $lines.ToArray()
    }
}
