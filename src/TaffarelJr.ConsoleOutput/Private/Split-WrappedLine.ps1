using namespace System.Collections.Generic

function Split-WrappedLine {
    <#
    .SYNOPSIS
        Splits text into console-ready lines: one break per embedded newline,
        plus a word-wrap break for any line too long to fit.
    .DESCRIPTION
        An embedded line break (CRLF, LF, or a lone CR) always starts a new
        line, even when Width would have allowed it to fit.
        A single word longer than Width is never split mid-word -
        it is left to overflow rather than hyphenated.
        A line's leading spaces stay on every line it wraps into, so an
        indented block stays indented; a line of nothing but spaces has no
        word to keep whole, so it is cut to Width. A tab becomes four spaces:
        its width on screen is not fixed, so it could not be fitted to a box.
        A line is measured by what shows on screen, so color codes in it do
        not count against Width.
    .OUTPUTS
        The lines, one at a time - always at least one, even for empty
        text.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory)]
        [int]$Width
    )

    $lines = [List[string]]::new()
    $paragraphs = Split-TextLine -Text $Text.Replace("`t", '    ')

    foreach ($paragraph in $paragraphs) {
        if ((Get-VisibleLength -Text $paragraph) -le $Width) {
            $lines.Add($paragraph)
            continue
        }

        $body = $paragraph.TrimStart()
        if (-not $body) {
            $lines.Add($paragraph.Substring(0, [Math]::Max(0, $Width)))
            continue
        }

        $indent = $paragraph.Substring(0, $paragraph.Length - $body.Length)
        $bodyWidth = [Math]::Max(1, $Width - $indent.Length)
        $current = ''
        foreach ($word in ($body -split ' ')) {
            $candidate = if ($current) { "$current $word" } else { $word }
            if ((Get-VisibleLength -Text $candidate) -gt $bodyWidth -and $current) {
                $lines.Add("$indent$current")
                $current = $word
            }
            else {
                $current = $candidate
            }
        }

        $lines.Add("$indent$current")
    }

    return $lines.ToArray()
}
