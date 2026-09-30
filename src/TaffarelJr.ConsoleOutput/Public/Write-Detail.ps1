function Write-Detail {
    <#
    .SYNOPSIS
        Adds a continuation line, indented under the message above it.
    .PARAMETER Text
        The line to print.
    .PARAMETER Indent
        Overrides the ambient indent (see Push-Indent) for this line only.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text,

        [int]$Indent = -1
    )

    process {
        Close-OpenLine
        # Three extra spaces land a Detail line under the marker text above it
        # (an emoji marker plus its trailing space or two).
        $prefix = (Format-LineIndent -Indent $Indent) + '   '
        Write-Host "$prefix$(Format-MessageText $Text)" -ForegroundColor DarkGray
    }
}
