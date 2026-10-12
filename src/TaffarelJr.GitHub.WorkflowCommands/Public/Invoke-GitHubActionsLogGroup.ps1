function Invoke-GitHubActionsLogGroup {
    <#
    .SYNOPSIS
        Runs a script block inside a collapsible log group, ending the
        group even when the block throws.
    .DESCRIPTION
        The block runs in the caller's own scope, as ForEach-Object's
        does, so a variable it assigns is the caller's variable, and
        whatever it outputs is passed on. An error it throws reaches the
        caller after the group is ended.

        PowerShell formats objects, a table especially, a moment after they
        are output, so the block's objects can print after the group has
        ended; pipe them to Out-Host inside the block to keep them in it.

        Groups do not nest, so the block should not start another.
    .PARAMETER Title
        The group's heading. May be empty.
    .PARAMETER ScriptBlock
        The code whose log lines the group collapses.
    .INPUTS
        None. This function takes nothing from the pipeline.
    .OUTPUTS
        System.Object. Whatever the script block outputs.
    .EXAMPLE
        Invoke-GitHubActionsLogGroup 'Restoring packages' {
            dotnet restore
        }

        Folds the restore's log lines under one heading; the group ends
        however the block finishes, a throw included.
    .EXAMPLE
        $version = Invoke-GitHubActionsLogGroup 'Reading version' {
            Get-Content ./VERSION
        }

        Passes the block's output on, here to a variable.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.WorkflowCommands/README.md
    .LINK
        Enter-GitHubActionsLogGroup
    .LINK
        Exit-GitHubActionsLogGroup
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Title,

        [Parameter(Mandatory, Position = 1)]
        [scriptblock]$ScriptBlock
    )

    try {
        $ErrorActionPreference = 'Stop'

        Enter-GitHubActionsLogGroup -Title $Title
        try {
            # Dot-sourced: a call with & gets a scope of its own, and the block's
            # assignments would be lost when it ends.
            . $ScriptBlock
        }
        finally {
            Exit-GitHubActionsLogGroup
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
