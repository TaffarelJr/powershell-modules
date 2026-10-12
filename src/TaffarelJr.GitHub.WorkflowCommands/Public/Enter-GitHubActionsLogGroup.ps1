function Enter-GitHubActionsLogGroup {
    <#
    .SYNOPSIS
        Starts a collapsible log group.
    .DESCRIPTION
        Pair with Exit-GitHubActionsLogGroup. The runner collapses
        everything written between the two under -Title by default.

        Groups do not nest: the runner has no notion of a group inside
        another, so start the next one only after ending this one. A
        script that throws before Exit-GitHubActionsLogGroup leaves the
        group open, folding the rest of the log into it;
        Invoke-GitHubActionsLogGroup ends the group whatever happens.

        PowerShell formats objects, a table especially, a moment after they
        are output, so an object output before Exit-GitHubActionsLogGroup
        can print after the group has ended; pipe it to Out-Host to keep it
        in the group.
    .PARAMETER Title
        The group's heading. May be empty.
    .INPUTS
        None. This function takes nothing from the pipeline.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Enter-GitHubActionsLogGroup -Title 'Restoring packages'

        Starts a group; the log lines written until
        Exit-GitHubActionsLogGroup fold under that heading.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.WorkflowCommands/README.md
    .LINK
        Exit-GitHubActionsLogGroup
    .LINK
        Invoke-GitHubActionsLogGroup
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Title
    )

    try {
        $ErrorActionPreference = 'Stop'

        Write-GitHubActionsCommand -Command 'group' -Data $Title
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
