function Exit-GitHubActionsLogGroup {
    <#
    .SYNOPSIS
        Ends the log group started by Enter-GitHubActionsLogGroup.
    .DESCRIPTION
        Writes the endgroup workflow command, so the log lines after it are
        no longer folded under the group's title. Groups do not nest, so one
        call ends the group that is open. Invoke-GitHubActionsLogGroup pairs
        the two for a script block, and ends the group even when the block
        throws.
    .INPUTS
        None. This function takes nothing from the pipeline.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Enter-GitHubActionsLogGroup -Title 'Restoring packages'
        dotnet restore
        Exit-GitHubActionsLogGroup

        Ends the group, so the lines after it are no longer folded under
        the heading.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.WorkflowCommands/README.md
    .LINK
        Enter-GitHubActionsLogGroup
    .LINK
        Invoke-GitHubActionsLogGroup
    #>
    [CmdletBinding()]
    param()

    try {
        $ErrorActionPreference = 'Stop'

        Write-GitHubActionsCommand -Command 'endgroup'
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
