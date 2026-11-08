function ConvertTo-GitHubPullRequestListArgument {
    <#
    .SYNOPSIS
        Returns one gh flag per name in a list of labels, assignees,
        reviewers, or projects, and throws for a blank name.
    .DESCRIPTION
        gh splits these flags' values at commas, so each name goes as a CSV
        field and stays one name, a comma or a quote in it included. A
        blank name would send the flag with nothing after it, which names
        nothing, so it throws instead. An empty list returns nothing.
    .PARAMETER Name
        The parameter the list came from, without its dash, for the message.
    .PARAMETER Flag
        The gh flag each name goes with, such as --label.
    .PARAMETER Value
        The names.
    .OUTPUTS
        One "<Flag>=<field>" per name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Flag,

        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Value
    )

    foreach ($element in $Value) {
        if ([string]::IsNullOrWhiteSpace($element)) {
            throw "-$Name has a blank element, which would send $Flag= with nothing after it." +
            " Give names, or leave -$Name out."
        }
    }

    if (-not $Value) {
        return
    }

    $fields = ConvertTo-GitHubCsvField -Value $Value
    foreach ($field in $fields) {
        "$Flag=$field"
    }
}
