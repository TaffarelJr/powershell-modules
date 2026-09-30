using namespace System.Collections.Generic

function Split-WrappedLine {
    <#
    .SYNOPSIS
        Splits text into console-ready lines: one break per embedded newline,
        plus a word-wrap break for any line too long to fit.
    .DESCRIPTION
        Embedded CR/LF always starts a new line,
        even when Width would have allowed it to fit.
        A single word longer than Width is never split mid-word -
        it is left to overflow rather than hyphenated.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory)]
        [int]$Width
    )

    $lines = [List[string]]::new()

    foreach ($paragraph in ($Text -split "`r?`n")) {
        if ($paragraph.Length -le $Width) {
            $lines.Add($paragraph)
            continue
        }

        $current = ''
        foreach ($word in ($paragraph -split ' ')) {
            $candidate = if ($current) {
                "$current $word"
            }
            else {
                $word
            }

            if ($candidate.Length -gt $Width -and $current) {
                $lines.Add($current)
                $current = $word
            }
            else {
                $current = $candidate
            }
        }

        $lines.Add($current)
    }

    return , $lines.ToArray()
}
