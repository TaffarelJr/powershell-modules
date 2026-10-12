function Enter-GitHubActionsLogGroup {
    <#
    .SYNOPSIS
        Starts a collapsible log group.
    .DESCRIPTION
        Pair with Exit-GitHubActionsLogGroup. The runner collapses
        everything written between the two under -Title by default.
    .PARAMETER Title
        The group's heading.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$Title
    )

    process {
        Write-GitHubActionsCommand -Command 'group' -Data $Title
    }
}
