function Write-Header {
    <#
    .SYNOPSIS
        Prints a rule, the given text centered, and a closing rule -
        open sides, for introducing a section that follows.
    .PARAMETER Text
        Embedded CR/LF starts a new line;
        a line too long for the console wraps at word boundaries
        instead of running past it.
    .PARAMETER Trim
        Shrinks the rule to fit the longest line instead of the full console width.
        A no-op once the text already needs the full width.
    .EXAMPLE
        Write-Header 'Build'
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text,

        [switch]$Trim
    )

    process {
        Write-Box -Text $Text -Trim:$Trim
    }
}
