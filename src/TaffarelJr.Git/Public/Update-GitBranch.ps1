function Update-GitBranch {
    <#
    .SYNOPSIS
        Pulls a branch from a remote: fetches it, then merges or rebases
        it onto the current branch.
    .DESCRIPTION
        Says which of the two it wants every time, so a user's pull.rebase
        setting - or git's refusal to guess when the branches have diverged -
        cannot turn a merge into a rebase, or into an error. With
        -FastForwardOnly it only ever moves the branch forward, and throws
        for a branch that has diverged instead of merging.

        Throws when no -Branch is given and HEAD is detached, since there
        is then no current branch to name.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Branch
        The remote branch to pull. Defaults to the current branch's
        configured upstream when that upstream is on -Remote, or, when it
        has none there, the remote branch of the same name.
    .PARAMETER Remote
        The remote to pull from. Defaults to 'origin'.
    .PARAMETER Rebase
        Rebases local commits onto the fetched branch instead of merging.
        Cannot be combined with -FastForwardOnly.
    .PARAMETER FastForwardOnly
        Only fast-forwards: a branch with commits the fetched one does not
        have is left as it is, and the call throws with git's reason. Cannot
        be combined with -Rebase.
    .PARAMETER RepoPath
        The repo to pull into. Omit it to use the current working
        directory.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Conflict, $false when the pull finished, and Paths: the conflicted
        files, left for the caller to resolve, or an empty array when there
        is no conflict.
    .EXAMPLE
        Update-GitBranch

        Pulls the current branch's upstream from origin, merging it in.
    .EXAMPLE
        Update-GitBranch -Branch 'main' -Remote 'origin' -Rebase

        Fetches main from origin and rebases the current branch onto it.
    .EXAMPLE
        Update-GitBranch -FastForwardOnly

        Moves the current branch up to its upstream, or throws when it has
        commits of its own.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Sync-GitRemote
    .LINK
        Push-GitCommit
    #>
    [CmdletBinding(DefaultParameterSetName = 'Merge', SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Branch,

        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Remote = 'origin',

        [Parameter(ParameterSetName = 'Rebase')]
        [switch]$Rebase,

        [Parameter(ParameterSetName = 'FastForward')]
        [switch]$FastForwardOnly,

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

        $source = $Branch
        if (-not $source) {
            $current = Get-GitBranch @inRepo
            if (-not $current) {
                throw 'Pulling failed: HEAD is detached, so there is no current branch to pull - pass -Branch.'
            }

            $source = $current
            $upstreamRemote = Get-GitConfig -Name "branch.$current.remote" @inRepo
            $upstreamBranch = Get-GitConfig -Name "branch.$current.merge" @inRepo
            if ($upstreamRemote -ceq $Remote -and $upstreamBranch) {
                $source = $upstreamBranch
            }
        }

        $mode = if ($Rebase) { '--rebase' } else { '--no-rebase' }
        $arguments = @('pull', $mode)
        if ($FastForwardOnly) {
            $arguments += '--ff-only'
        }

        $arguments += @($Remote, $source)

        $target = Get-GitRepoLocation -Activity 'Pulling' -RepoPath $RepoPath
        Assert-GitRemoteSource -Name $Remote -Activity 'Pulling' -RepoPath $RepoPath
        $from = Hide-UrlCredential -Text $Remote
        $how = if ($Rebase) { 'rebasing' } elseif ($FastForwardOnly) { 'fast-forwarding only' } else { 'merging' }
        $branch = $source -creplace '^refs/heads/', ''
        if (-not $PSCmdlet.ShouldProcess($target, "Pull branch $branch from remote $from, $how")) {
            return
        }

        $read = Invoke-GitCommand -Activity 'Pulling' -Arguments $arguments -RepoPath $RepoPath -Tolerant
        if ($read.Ok) {
            return [PSCustomObject]@{
                Conflict = $false
                Paths    = @()
            }
        }

        # A pull that stops on a conflict exits 1; anything else is a failure to
        # report, not a paused merge or rebase to look into.
        if ($read.ExitCode -eq 1) {
            $stopped = if ($Rebase) {
                Test-GitRebaseInProgress @inRepo
            }
            else {
                Resolve-GitRef -Ref 'MERGE_HEAD' @inRepo
            }

            if ($stopped) {
                $conflicts = @(Get-GitConflict @inRepo)
                if ($conflicts.Count -gt 0) {
                    return [PSCustomObject]@{
                        Conflict = $true
                        Paths    = $conflicts
                    }
                }
            }
        }

        throw "Pulling failed: $($read.Message)"
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
