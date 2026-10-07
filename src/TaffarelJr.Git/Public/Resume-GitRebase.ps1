function Resume-GitRebase {
    <#
    .SYNOPSIS
        Continues a rebase that paused on a conflict, once every
        conflicted path has been resolved and staged.
    .DESCRIPTION
        Replays the rest of the commits; no editor is opened for a commit
        message. A rebase that stops again returns Conflict with the new
        Paths, and a folder with no rebase under way throws.

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
        System.Management.Automation.PSCustomObject
        Conflict, $false when the rebase finished, and Paths: the next
        conflicted files, or an empty array when there is no conflict.
    .EXAMPLE
        Resume-GitRebase

        Continues a rebase that paused, once its conflicts are resolved and
        staged.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Start-GitRebase
    .LINK
        Stop-GitRebase
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
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

        $target = Get-GitRepoLocation -Activity 'Continuing the rebase' -RepoPath $RepoPath
        if (-not (Test-GitRebaseInProgress @inRepo)) {
            throw "Continuing the rebase failed: no rebase is in progress in '$target'."
        }

        if (-not $PSCmdlet.ShouldProcess($target, 'Continue the rebase')) {
            return
        }

        $read = Invoke-GitCommand -Activity 'Continuing the rebase' `
            -Arguments @('rebase', '--continue') -RepoPath $RepoPath -Tolerant
        if ($read.Ok) {
            return [PSCustomObject]@{
                Conflict = $false
                Paths    = @()
            }
        }

        if (Test-GitRebaseInProgress @inRepo) {
            $conflicts = @(Get-GitConflict @inRepo)
            if ($conflicts.Count -gt 0) {
                return [PSCustomObject]@{ Conflict = $true; Paths = $conflicts }
            }
        }

        throw "Continuing the rebase failed: $($read.Message)"
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
