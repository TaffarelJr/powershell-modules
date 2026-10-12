function Write-GitHubActionsNotice {
    <#
    .SYNOPSIS
        Writes a notice annotation, shown inline on the run and on any
        pull request it belongs to.
    .PARAMETER Message
        The text to show.
    .PARAMETER File
        The file the annotation points at, relative to the repository
        root.
    .PARAMETER Line
        The line the annotation points at. Requires -File.
    .PARAMETER EndLine
        The last line of the range. Omit to point at a single line.
    .PARAMETER Col
        The column the annotation points at. Requires -Line.
    .PARAMETER EndColumn
        The last column of the range. Omit to point at a single column.
    .PARAMETER Title
        A short heading shown above the message.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Message,

        [string]$File,
        [int]$Line,
        [int]$EndLine,
        [int]$Col,
        [int]$EndColumn,
        [string]$Title
    )

    process {
        Write-GitHubActionsAnnotation -Command 'notice' -Message $Message `
            -File $File -Line $Line -EndLine $EndLine -Col $Col -EndColumn $EndColumn -Title $Title
    }
}
