function Write-Doing {
    <#
    .SYNOPSIS
        Announces what a step is about to attempt, on a line left open.
    .DESCRIPTION
        Pair it with Write-Done.
        Anything printed in between closes this line first
        instead of running on to the end of it.
    .PARAMETER Text
        What the step is attempting.
    .PARAMETER Indent
        Overrides the ambient indent (see Push-Indent) for this line only.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$Text,

        [int]$Indent = -1
    )

    process {
        Close-OpenLine
        $prefix = Get-LineIndent -Indent $Indent
        Write-Host "${prefix}▶ $Text ..." -NoNewline -ForegroundColor Cyan
        $script:LineOpen = $true
    }
}
