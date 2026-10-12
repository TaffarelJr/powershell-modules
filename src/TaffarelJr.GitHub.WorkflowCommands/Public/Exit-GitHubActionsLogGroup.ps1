function Exit-GitHubActionsLogGroup {
    <#
    .SYNOPSIS
        Ends the log group started by Enter-GitHubActionsLogGroup.
    #>
    param()

    Write-GitHubActionsCommand -Command 'endgroup'
}
