function Write-GitHubActionsAnnotation {
    <#
    .SYNOPSIS
        Writes a notice, warning, or error annotation.
    .DESCRIPTION
        Not exported. Shared by Write-GitHubActionsNotice, -Warning, and
        -Error, which differ only in which workflow command they name.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Message,

        [string]$File,
        [int]$Line,
        [int]$EndLine,
        [int]$Col,
        [int]$EndColumn,
        [string]$Title
    )

    $properties = [ordered]@{}
    if ($File) { $properties['file'] = $File }
    if ($Line -gt 0) { $properties['line'] = $Line }
    if ($EndLine -gt 0) { $properties['endLine'] = $EndLine }
    if ($Col -gt 0) { $properties['col'] = $Col }
    if ($EndColumn -gt 0) { $properties['endColumn'] = $EndColumn }
    if ($Title) { $properties['title'] = $Title }

    Write-GitHubActionsCommand -Command $Command -Properties $properties -Data $Message
}
