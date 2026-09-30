function Write-Warn {
    <#
    .SYNOPSIS
        Reports something worth attention that does not stop the run.
    .DESCRIPTION
        Named Warn, not Warning,
        so it never shadows the built-in Write-Warning cmdlet
        and its warning-stream semantics
        ($WarningPreference, -WarningAction, -WarningVariable).
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
        $prefix = Get-LineIndent -Indent $Indent
        Write-Host "${prefix}⚠️  $(Format-MessageText $Text)" -ForegroundColor Yellow
    }
}
