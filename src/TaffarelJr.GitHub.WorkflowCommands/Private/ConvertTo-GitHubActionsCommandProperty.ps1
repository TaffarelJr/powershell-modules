function ConvertTo-GitHubActionsCommandProperty {
    <#
    .SYNOPSIS
        Escapes a workflow command's own property value.
    .DESCRIPTION
        Not exported. A property value sits inside a comma-separated
        key=value list, so on top of ConvertTo-GitHubActionsCommandData's
        own escaping, it also escapes : and , - the two characters that
        would otherwise be mistaken for part of that list's syntax.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    return (ConvertTo-GitHubActionsCommandData -Value $Value) -replace ':', '%3A' -replace ',', '%2C'
}
