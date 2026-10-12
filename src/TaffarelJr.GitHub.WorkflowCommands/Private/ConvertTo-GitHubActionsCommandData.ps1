function ConvertTo-GitHubActionsCommandData {
    <#
    .SYNOPSIS
        Escapes a workflow command's own data segment.
    .DESCRIPTION
        Not exported. % goes first, since the runner reads it as the
        start of these very escape sequences - escaping it after CR or
        LF would double-escape the percent they introduce.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    return $Value -replace '%', '%25' -replace "`r", '%0D' -replace "`n", '%0A'
}
