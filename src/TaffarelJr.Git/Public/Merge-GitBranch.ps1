function Merge-GitBranch {
    <#
    .SYNOPSIS
        Merges a ref into the current branch.
    .DESCRIPTION
        Fast-forwards when it can, and otherwise makes a merge commit,
        whatever merge.ff in the user's config says.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Ref
        The ref to merge in.
    .PARAMETER NoFastForward
        Always creates a merge commit, even when the current branch could
        simply fast-forward.
    .PARAMETER RepoPath
        The repo to merge in. Omit it to use the current working
        directory.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Conflict, $false for a clean merge, and Paths: the conflicted files,
        left for the caller to resolve, or an empty array when there is no
        conflict.
    .EXAMPLE
        Merge-GitBranch -Ref 'feature/x'

        Merges feature/x into the current branch and reports any conflict.
    .EXAMPLE
        Merge-GitBranch -Ref 'feature/x' -NoFastForward -WhatIf

        Shows the merge commit that would be made, without merging.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitConflict
    .LINK
        Resolve-GitConflict
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Ref,

        [switch]$NoFastForward,

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

        $fastForward = if ($NoFastForward) { '--no-ff' } else { '--ff' }
        $arguments = @('merge', '--no-edit', $fastForward, $Ref)
        $target = Get-GitRepoLocation -Activity "Merging $Ref" -RepoPath $RepoPath
        Assert-GitRevision -Revision $Ref -Activity "Merging $Ref" -RepoPath $RepoPath
        $action = "Merge $Ref"
        if ($NoFastForward) {
            $action += ', always with a merge commit'
        }

        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            return
        }

        $read = Invoke-GitCommand -Activity "Merging $Ref" -Arguments $arguments -RepoPath $RepoPath -Tolerant
        if ($read.Ok) {
            return [PSCustomObject]@{
                Conflict = $false
                Paths    = @()
            }
        }

        # A merge that stops on a conflict exits 1, and MERGE_HEAD only exists
        # while it is stopped partway.
        $inRepo = @{}
        if ($PSBoundParameters.ContainsKey('RepoPath')) {
            $inRepo.RepoPath = $RepoPath
        }

        if ($read.ExitCode -eq 1 -and (Resolve-GitRef -Ref 'MERGE_HEAD' @inRepo)) {
            $conflicts = @(Get-GitConflict @inRepo)
            if ($conflicts.Count -gt 0) {
                return [PSCustomObject]@{
                    Conflict = $true
                    Paths    = $conflicts
                }
            }
        }

        throw "Merging $Ref failed: $($read.Message)"
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
