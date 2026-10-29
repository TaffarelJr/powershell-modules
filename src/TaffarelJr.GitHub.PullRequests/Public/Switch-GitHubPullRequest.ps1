function Switch-GitHubPullRequest {
    <#
    .SYNOPSIS
        Checks a pull request's head out as a local branch.
    .DESCRIPTION
        Works on the current directory's clone, the way gh pr checkout
        does: the pull request must be named, since gh would otherwise
        offer a picker it cannot show here. -WhatIf and -Confirm name the
        checkout that would change by its full path: the -Worktree path, or
        the current location.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER PullRequest
        The pull request: its number, URL, or head branch, or a pull
        request object.
    .PARAMETER Branch
        The local branch name to use. gh's default is the head branch's
        own name. A blank one throws, and so does one given along with
        -Detach.
    .PARAMETER Detach
        Checks the commit out with a detached HEAD instead of a branch.
    .PARAMETER Force
        Resets an existing local branch of that name to the pull
        request's latest state with git reset --hard, which throws away
        uncommitted changes to tracked files. Resets without asking by
        default; -Confirm asks first.
    .PARAMETER RecurseSubmodules
        Updates every submodule after the checkout.
    .PARAMETER Worktree
        Checks the pull request out into a new worktree at this path
        instead of switching the current one. A relative path is taken
        from the current location, and ~ is the home folder. A blank one
        throws. Needs gh 2.98 or later.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form or as a URL, or a
        repository object. Omit it to use the current directory's
        repository; given as $null, it throws. A pull request given by URL
        or object is in the repository it names; one in a different
        repository than this throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object
        A pull request: its number, URL, or head branch, or a pull request
        object such as Get-GitHubPullRequest returns. Binds to -PullRequest.
    .OUTPUTS
        None
    .EXAMPLE
        Switch-GitHubPullRequest -PullRequest 42

        Checks pull request 42 out in the current directory's clone, as a
        local branch named after its head branch.
    .EXAMPLE
        Switch-GitHubPullRequest -PullRequest 42 -Worktree '../pr-42'

        Checks pull request 42 out into a new worktree at ../pr-42.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.PullRequests/README.md
    .LINK
        Get-GitHubPullRequest
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$PullRequest,

        [string]$Branch,

        [switch]$Detach,

        [switch]$Force,

        [switch]$RecurseSubmodules,

        [string]$Worktree,

        [object]$Repository
    )

    begin {
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

            if ($PSBoundParameters.ContainsKey('Branch') -and $Detach) {
                throw '-Branch and -Detach cannot be used together: a detached HEAD is on no branch. Give only one.'
            }

            if ($PSBoundParameters.ContainsKey('Branch') -and [string]::IsNullOrWhiteSpace($Branch)) {
                throw '-Branch is blank: give a branch name, or leave it out.'
            }

            if ($PSBoundParameters.ContainsKey('Worktree') -and [string]::IsNullOrWhiteSpace($Worktree)) {
                throw "-Worktree is blank: give the worktree's path, or leave it out."
            }

            $given = $PSBoundParameters.ContainsKey('Repository')
            $repositoryReference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $resolve = @{
                BoundParameters = $PSBoundParameters
                Repository      = $repositoryReference
            }
            $target = Resolve-GitHubPullRequestTarget @resolve
            $arguments = @('pr', 'checkout') + $target.Arguments
            $subject = Format-GitHubPullRequestTarget -Target $target -Repository $repositoryReference
            $action = "Check out $subject"
            if ($Branch) {
                $arguments += "--branch=$Branch"
                $shownBranch = Hide-UrlCredential -Text $Branch
                $action += " as branch $shownBranch"
            }

            if ($Detach) {
                $arguments += '--detach'
                $action += ' with a detached HEAD'
            }

            if ($Worktree) {
                $action += ' into a new worktree'
            }

            if ($Force) {
                $arguments += '--force'
                $action += ', resetting that branch if it exists and discarding uncommitted changes to tracked files'
            }

            if ($RecurseSubmodules) {
                $arguments += '--recurse-submodules'
                $action += ', updating every submodule'
            }

            $checkout = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation.ProviderPath
            $shownCheckout = Hide-UrlCredential -Text $checkout
            if ($Worktree) {
                $arguments += "--worktree=$(Resolve-GitHubPath -Path $Worktree)"
                $shownCheckout = Resolve-GitHubPath -Path (Hide-UrlCredential -Text $Worktree)
            }

            if (-not $PSCmdlet.ShouldProcess($shownCheckout, $action)) {
                return
            }

            $command = @{
                Activity   = "Checking out $($target.Name)"
                Arguments  = $arguments
                Repository = $repositoryReference
            }
            Invoke-GitHubCommand @command | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
