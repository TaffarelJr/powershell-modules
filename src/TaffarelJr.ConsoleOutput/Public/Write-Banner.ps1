function Write-Banner {
    <#
    .SYNOPSIS
        Prints the given text left-justified inside a full box -
        corners, top and bottom, and a side character on every line -
        for a standalone announcement rather than a section introduction.
    .PARAMETER Text
        Embedded CR/LF starts a new line;
        a line too long for the console wraps at word boundaries
        instead of running past it.
    .PARAMETER Trim
        Shrinks the box to fit the longest line instead of the full console width.
        A no-op once the text already needs the full width.
    .EXAMPLE
        Write-Banner 'BUILD FAILED'
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text,

        [switch]$Trim
    )

    process {
        Write-Box -Text $Text -Trim:$Trim -Bordered
    }
}
