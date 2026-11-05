function Start-GitRebase {
    <#
    .SYNOPSIS
        Starts replaying the current branch's commits onto another ref.
    .DESCRIPTION
        Not interactive - this is for rebasing onto a different base, not
        for reordering or squashing commits by hand. A conflict leaves the
        rebase paused; check Test-GitRebaseInProgress, resolve the
        conflicted paths (Get-GitConflict, Resolve-GitConflict), stage
        them, and call Resume-GitRebase - or Stop-GitRebase to abandon it.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Ref
        The ref to rebase onto.
    .PARAMETER RepoPath
        The repo to rebase in. Omit it to use the current working
        directory.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Conflict, $false when the rebase finished cleanly, and Paths: the
        conflicted files, or an empty array when there is no conflict.
    .EXAMPLE
        Start-GitRebase -Ref 'origin/main'

        Replays the current branch's commits onto origin/main.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Resume-GitRebase
    .LINK
        Stop-GitRebase
    .LINK
        Test-GitRebaseInProgress
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Ref,

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

        $target = Get-GitRepoLocation -Activity "Rebasing onto $Ref" -RepoPath $RepoPath
        Assert-GitRevision -Revision $Ref -Activity "Rebasing onto $Ref" -RepoPath $RepoPath
        if (-not $PSCmdlet.ShouldProcess($target, "Rebase onto $Ref")) {
            return
        }

        $read = Invoke-GitCommand -Activity "Rebasing onto $Ref" `
            -Arguments @('rebase', $Ref) -RepoPath $RepoPath -Tolerant
        if ($read.Ok) {
            return [PSCustomObject]@{
                Conflict = $false
                Paths    = @()
            }
        }

        $inRepo = @{}
        if ($PSBoundParameters.ContainsKey('RepoPath')) {
            $inRepo.RepoPath = $RepoPath
        }

        if (Test-GitRebaseInProgress @inRepo) {
            $conflicts = @(Get-GitConflict @inRepo)
            if ($conflicts.Count -gt 0) {
                return [PSCustomObject]@{ Conflict = $true; Paths = $conflicts }
            }
        }

        throw "Rebasing onto $Ref failed: $($read.Message)"
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
