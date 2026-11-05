function Stop-GitRebase {
    <#
    .SYNOPSIS
        Abandons an in-progress rebase, restoring the branch to where it
        was before Start-GitRebase.
    .DESCRIPTION
        Runs git rebase --abort: the commits replayed so far and the
        conflict resolutions made are dropped, and the branch is back where
        it started. A folder with no rebase under way throws.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER RepoPath
        The repo to act in. Omit it to use the current working directory.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Stop-GitRebase

        Abandons the rebase under way and restores the branch.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Start-GitRebase
    .LINK
        Test-GitRebaseInProgress
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

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

        $inRepo = @{}
        if ($PSBoundParameters.ContainsKey('RepoPath')) {
            $inRepo.RepoPath = $RepoPath
        }

        $target = Get-GitRepoLocation -Activity 'Aborting the rebase' -RepoPath $RepoPath
        if (-not (Test-GitRebaseInProgress @inRepo)) {
            throw "Aborting the rebase failed: no rebase is in progress in '$target'."
        }

        if (-not $PSCmdlet.ShouldProcess($target, 'Abort the rebase')) {
            return
        }

        Invoke-GitCommand -Activity 'Aborting the rebase' `
            -Arguments @('rebase', '--abort') -RepoPath $RepoPath | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
