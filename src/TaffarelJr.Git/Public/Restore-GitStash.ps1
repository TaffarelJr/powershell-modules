function Restore-GitStash {
    <#
    .SYNOPSIS
        Restores a stash and removes it from the stash list.
    .DESCRIPTION
        Restores whichever stash -Index names, not necessarily the one you
        just saved: Save-GitStash returns $false when there was nothing to
        stash, and restoring after that would apply an older, unrelated one.

        A stash that conflicts with commits made since it was saved returns
        Conflict with the conflicted Paths, like Merge-GitBranch: the
        conflict markers are left in those files, and the stash is kept in
        the list. Resolve the files with Resolve-GitConflict or by hand; the
        stash stays in the list until git's own 'git stash drop' removes it.
        A stash that would overwrite uncommitted changes is refused by git,
        and throws, as does any other failure. So does an index that already
        has unresolved conflicts, from a merge say: the stash is then never
        applied, and stays in the list.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Index
        Which stash to restore, where 0 is the most recently saved.
        Defaults to 0.
    .PARAMETER RepoPath
        The repo to restore into. Omit it to use the current working
        directory.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Conflict, $false when the stash was restored and removed, and Paths:
        the conflicted files, or an empty array when there is no conflict.
    .EXAMPLE
        Restore-GitStash

        Restores the newest stash and drops it from the list.
    .EXAMPLE
        Restore-GitStash -Index 2 -WhatIf

        Shows that the third newest stash would be restored, without doing it.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Save-GitStash
    .LINK
        Get-GitStash
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [ValidateRange('NonNegative')]
        [int]$Index = 0,

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

        $unresolved = @(Get-GitConflict @inRepo)
        if ($unresolved.Count -gt 0) {
            throw "Restoring the stash failed: the index already has unresolved conflicts" +
            " ($($unresolved -join ', ')). Resolve them before restoring a stash; the stash is kept."
        }

        $root = Get-GitRepoLocation -Activity 'Restoring the stash' -RepoPath $RepoPath
        $stashes = @(Get-GitStash @inRepo)
        if ($Index -ge $stashes.Count) {
            throw "Restoring the stash failed: there is no stash@{$Index}."
        }

        $action = 'Restore stash, then drop it unless it conflicts'
        if (-not $PSCmdlet.ShouldProcess("$root stash@{$Index}", $action)) {
            return
        }

        $read = Invoke-GitCommand -Activity 'Restoring the stash' `
            -Arguments @('stash', 'pop', "stash@{$Index}") -RepoPath $RepoPath -Tolerant
        if ($read.Ok) {
            return [PSCustomObject]@{
                Conflict = $false
                Paths    = @()
            }
        }

        # A pop that stops on a conflict exits 1; anything else is a failure to
        # report.
        if ($read.ExitCode -eq 1) {
            $conflicts = @(Get-GitConflict @inRepo)
            if ($conflicts.Count -gt 0) {
                return [PSCustomObject]@{
                    Conflict = $true
                    Paths    = $conflicts
                }
            }
        }

        throw "Restoring the stash failed (exit $($read.ExitCode)): $($read.Message)"
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
