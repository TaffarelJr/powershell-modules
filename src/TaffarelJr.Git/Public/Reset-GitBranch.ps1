function Reset-GitBranch {
    <#
    .SYNOPSIS
        Moves the current branch to a different commit.
    .DESCRIPTION
        Points the current branch at -Ref, and with -Mode decides what
        happens to the index and the working tree. -Mode Hard also abandons
        a merge in progress, and discards every uncommitted change with it.
        Nothing asks for confirmation unless -Confirm is given.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Ref
        Where to move the branch to. Defaults to HEAD, which resets
        without moving the branch - useful for just un-staging everything
        with the default -Mode, including in a repository with no commits
        yet. A ref named like a file or folder is still read as a ref.
    .PARAMETER Mode
        Soft leaves the working tree and index untouched, so everything
        since -Ref becomes staged again. Mixed (the default, matching
        git's own) also un-stages, leaving the working tree alone. Hard
        discards uncommitted changes entirely - the one genuinely
        destructive option here, since nothing after this can recover
        them.
    .PARAMETER RepoPath
        The repo to reset. Omit it to use the current working directory.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Reset-GitBranch

        Unstages everything and leaves the working tree as it is.
    .EXAMPLE
        Reset-GitBranch -Ref 'origin/main' -Mode Hard

        Moves the branch to origin/main and discards uncommitted changes.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Switch-GitBranch
    .LINK
        Save-GitStash
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Ref,

        [ValidateSet('Soft', 'Mixed', 'Hard')]
        [string]$Mode = 'Mixed',

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

        $arguments = @('reset', "--$($Mode.ToLowerInvariant())")
        if ($Ref) {
            $arguments += @($Ref, '--')
        }

        $target = if ($Ref) { $Ref } else { 'HEAD' }
        $activity = "Resetting to $target"
        $repository = Get-GitRepoLocation -Activity $activity -RepoPath $RepoPath -AllowBare:($Mode -eq 'Soft')

        # HEAD is left to git: it resets to it even before the first commit.
        if ($target -cne 'HEAD') {
            Assert-GitRevision -Revision $target -Activity $activity -RepoPath $RepoPath
        }

        $effect = switch ($Mode) {
            'Soft' { 'keeping the changes staged' }
            'Mixed' { 'unstaging the changes' }
            'Hard' { 'discarding uncommitted changes' }
        }

        if (-not $PSCmdlet.ShouldProcess($repository, "Reset ($Mode) to $target, $effect")) {
            return
        }

        Invoke-GitCommand -Activity $activity -Arguments $arguments -RepoPath $RepoPath | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
