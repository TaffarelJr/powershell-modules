function Remove-GitBranch {
    <#
    .SYNOPSIS
        Deletes a local branch.
    .DESCRIPTION
        Deletes the branch from this repository only; a remote's copy is
        left alone. A branch that does not exist throws, and so, without
        -Force, does one that is not fully merged. Nothing asks for
        confirmation unless -Confirm is given.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The branch to delete. Accepted from the pipeline, including by
        property name, so a filtered list from Get-GitBranch -List can be
        piped straight in.
    .PARAMETER Force
        Deletes it even if it is not fully merged. Without it, git refuses
        an unmerged branch rather than risk losing commits.
    .PARAMETER RepoPath
        The repo to delete it from. Omit it to use the current working
        directory.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.String
        The name of a branch, or an object with a Name property, such as the
        output of Get-GitBranch.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Remove-GitBranch -Name 'feature/x'

        Deletes a local branch, refusing one that is not fully merged.
    .EXAMPLE
        Get-GitBranch -List | Where-Object { $_ -like 'feature/*' } |
            Remove-GitBranch

        Deletes every local branch under feature/.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitBranch
    .LINK
        New-GitBranch
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Name,

        [switch]$Force,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
                $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Confirm')) {
                $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            $flag = if ($Force) { '-D' } else { '-d' }
            $activity = "Deleting branch $Name"
            $root = Get-GitRepoLocation -Activity $activity -RepoPath $RepoPath -AllowBare
            $exists = Invoke-GitCommand -Activity $activity `
                -Arguments @('show-ref', '--verify', '--quiet', "refs/heads/$Name") -RepoPath $RepoPath -Tolerant
            if (-not $exists.Ok) {
                throw "$activity failed: there is no branch named '$Name'."
            }

            $action = if ($Force) { 'Delete branch, even if not fully merged' } else { 'Delete branch' }
            if (-not $PSCmdlet.ShouldProcess("$root branch $Name", $action)) {
                return
            }

            Invoke-GitCommand -Activity $activity `
                -Arguments @('branch', $flag, $Name) -RepoPath $RepoPath | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
