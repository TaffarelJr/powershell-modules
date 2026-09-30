function Write-Success {
    <#
    .SYNOPSIS
        Reports that something was done.
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
        $prefix = Format-LineIndent -Indent $Indent
        Write-Host "${prefix}✅ $(Format-MessageText $Text)" -ForegroundColor Green
    }
}
