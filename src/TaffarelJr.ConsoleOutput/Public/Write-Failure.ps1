function Write-Failure {
    <#
    .SYNOPSIS
        Reports that something did not succeed, on its own line.
    .DESCRIPTION
        Prints a single formatted line -
        it does not parse or render an ErrorRecord.
        A terminating error is better served by a plain throw
        and PowerShell's own error display;
        this is for a non-terminating "this one thing failed" line
        alongside Write-Success/Write-Skip.
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
        Write-Host "${prefix}❌ $(Format-MessageText $Text)" -ForegroundColor Red
    }
}
