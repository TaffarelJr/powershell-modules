function Push-GitCommit {
    <#
    .SYNOPSIS
        Pushes a branch to a remote.
    .DESCRIPTION
        Success is read from --porcelain's machine-readable flag rather
        than git's summary line, which is localized.

        The local branch is pushed by its full name, to the remote branch
        of the same name, so a tag that shares the name is never pushed in
        its place. Throws when no -Branch is given and HEAD is detached,
        since there is then no current branch to push.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Branch
        The local branch to push: its name, or shorthand git reads as a
        branch, such as 'HEAD' or 'refs/heads/<name>'. A tag, a remote
        branch, or a commit throws. Defaults to the current branch.
    .PARAMETER Remote
        The remote to push to. Defaults to 'origin'.
    .PARAMETER SetUpstream
        Also sets the branch's upstream to this remote and branch.
    .PARAMETER Force
        Pushes even when the remote has commits this branch does not,
        using --force-with-lease: it still refuses if the remote moved
        since this branch last saw it, unlike a bare force push. Cannot be
        combined with -ForceWithoutLease.
    .PARAMETER ForceWithoutLease
        A bare --force push, bypassing the lease check -Force applies.
        Only for a branch nothing else can be racing, such as one owned
        entirely by automation and recreated every run - it can silently
        discard someone else's work on a shared branch. Cannot be combined
        with -Force.
    .PARAMETER RepoPath
        The repo to push from. Omit it to use the current working
        directory.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.Boolean
        $true when something was sent, $false when the remote was already up to
        date.
    .EXAMPLE
        Push-GitCommit -SetUpstream

        Pushes the current branch to origin and sets it as the upstream.
    .EXAMPLE
        Push-GitCommit -Branch 'feature/x' -Remote 'origin' -Force

        Pushes a branch even when the remote has moved, but only if the remote
        has not changed since this branch last saw it.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Update-GitBranch
    .LINK
        Sync-GitRemote
    #>
    [CmdletBinding(DefaultParameterSetName = 'Lease', SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Branch,

        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Remote = 'origin',

        [switch]$SetUpstream,

        [Parameter(ParameterSetName = 'Lease')]
        [switch]$Force,

        [Parameter(Mandatory, ParameterSetName = 'NoLease')]
        [switch]$ForceWithoutLease,

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

        $arguments = @('push', '--porcelain')
        if ($SetUpstream) {
            $arguments += '-u'
        }

        if ($ForceWithoutLease) {
            $arguments += '--force'
        }
        elseif ($Force) {
            $arguments += '--force-with-lease'
        }

        $inRepo = @{}
        if ($PSBoundParameters.ContainsKey('RepoPath')) {
            $inRepo.RepoPath = $RepoPath
        }

        # Resolved explicitly rather than left for git to infer: 'push -u origin'
        # with no branch name fails outright, since -u has nothing to attach the
        # new upstream to even though a plain push would have inferred the
        # current branch from push.default.
        $branchName = if ($Branch) {
            Resolve-GitBranchName -Name $Branch -Activity 'Pushing' -RepoPath $RepoPath
        }
        else {
            Get-GitBranch @inRepo
        }

        if (-not $branchName) {
            throw 'Pushing failed: HEAD is detached, so there is no current branch to push - pass -Branch.'
        }

        $arguments += @($Remote, "refs/heads/${branchName}:refs/heads/$branchName")

        $root = Get-GitRepoLocation -Activity 'Pushing' -RepoPath $RepoPath -AllowBare
        Assert-GitRemoteSource -Name $Remote -Activity 'Pushing' -RepoPath $RepoPath
        $destination = Hide-UrlCredential -Text $Remote
        $action = if ($ForceWithoutLease) {
            "Force push to $destination"
        }
        elseif ($Force) {
            "Force push, with a lease, to $destination"
        }
        else {
            "Push to $destination"
        }

        if ($SetUpstream) {
            $action += ', setting it as the upstream'
        }

        if (-not $PSCmdlet.ShouldProcess("$root branch $branchName", $action)) {
            return
        }

        $out = Invoke-GitCommand -Activity 'Pushing' -Arguments $arguments -RepoPath $RepoPath
        if (($out -join "`n") -match '(?m)^=\s') {
            return $false
        }

        return $true
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
