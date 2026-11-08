function New-GitHubFork {
    <#
    .SYNOPSIS
        Forks a repository and returns the new fork's URL.
    .DESCRIPTION
        Adding the fork as a git remote is something only a fork of the
        current directory's repository can do: gh refuses --remote, even
        --remote=false, with a named repository, and ignores
        --remote-name. So -Remote and -RemoteName throw with -Repository,
        and nothing about a remote is sent for a named repository.
        -RemoteName names the remote -Remote adds, so it throws without
        -Remote too.

        -Clone and -Remote run git, which can stop to ask for credentials
        or an SSH passphrase; nothing here answers it, so have those set
        up before a run nobody watches.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Repository
        The repository to fork, in [HOST/]OWNER/REPO form or as a URL, or a
        repository object such as one a search returned. Omit it to fork
        the current directory's repository; $null throws rather than
        meaning that.
    .PARAMETER Organization
        Creates the fork in this organization instead of under the
        authenticated user: an organization name, letters, digits, and
        dashes. A blank one is refused.
    .PARAMETER ForkName
        A different name for the fork. A blank one is refused.
    .PARAMETER DefaultBranchOnly
        Copies only the default branch into the fork.
    .PARAMETER Clone
        Clones the fork into a new folder in the current directory. gh
        clones only the fork of a named repository: without -Repository it
        ignores the switch.
    .PARAMETER Remote
        Adds the fork as a git remote of the current directory's
        repository, as gh's --remote switch. Only without -Repository.
    .PARAMETER RemoteName
        The name for that remote, gh's --remote-name. gh's default is
        origin, renaming any existing origin to upstream. Only with
        -Remote, and without -Repository. A blank one is refused.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object
        The repository to fork - OWNER/REPO text, a URL, or a repository
        object such as one a search returned.
    .OUTPUTS
        System.String
        The new fork's URL. Nothing when the fork already existed: gh then
        only says so on its error stream. Nothing from a gh older than
        2.65 either, which prints no URL when not run in a terminal.
    .EXAMPLE
        New-GitHubFork -Repository 'OWNER/REPO'

        Forks OWNER/REPO under the authenticated user and returns the new
        fork's URL.
    .EXAMPLE
        New-GitHubFork -Repository 'OWNER/REPO' -Organization 'ORG' `
            -DefaultBranchOnly

        Forks only the default branch of OWNER/REPO into the organization ORG.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Sync-GitHubRepository
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [object]$Repository,

        [ValidateScript({ Assert-GitHubOrganizationName -Name $_ -AllowBlank })]
        [string]$Organization,

        [string]$ForkName,

        [switch]$DefaultBranchOnly,

        [switch]$Clone,

        [switch]$Remote,

        [string]$RemoteName
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

            $blank = [ordered]@{
                Organization = 'the fork would go to your own account'
                ForkName     = 'the fork would keep the original name'
                RemoteName   = 'gh would name the remote origin'
            }
            foreach ($name in $blank.PSBase.Keys) {
                $present = $PSBoundParameters.ContainsKey($name)
                if ($present -and [string]::IsNullOrWhiteSpace($PSBoundParameters[$name])) {
                    throw "-$name was given but is blank, so $($blank[$name]). Give a value, or leave -$name off."
                }
            }

            $remoteGiven = $PSBoundParameters.ContainsKey('Remote') -or $PSBoundParameters.ContainsKey('RemoteName')
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $given = $PSBoundParameters.ContainsKey('Repository')
            $target = @(Resolve-GitHubRepositoryArgument -Value $Repository -Given $given)
            if ($target.Count -gt 0 -and $remoteGiven) {
                throw '-Remote and -RemoteName add a remote to the current directory''s clone, which only a fork of' +
                ' that clone''s repository can do - gh refuses them with a named repository.'
            }

            if ($RemoteName -and -not $Remote) {
                throw '-RemoteName works only with -Remote: it names the remote -Remote adds, and gh ignores it' +
                ' otherwise. Give -Remote too, or leave -RemoteName off.'
            }

            $arguments = @('repo', 'fork') + $target + @("--clone=$($Clone.ToString().ToLowerInvariant())")
            if ($target.Count -eq 0) {
                $arguments += "--remote=$($Remote.ToString().ToLowerInvariant())"
            }

            if ($Organization) {
                $arguments += "--org=$Organization"
            }

            if ($ForkName) {
                $arguments += "--fork-name=$ForkName"
            }

            if ($DefaultBranchOnly) {
                $arguments += '--default-branch-only'
            }

            if ($RemoteName) {
                $arguments += "--remote-name=$RemoteName"
            }

            $activity = "Forking repository $target"
            if ($target.Count -eq 0) {
                $activity = "Forking the current directory's repository"
            }

            $action = 'Fork repository'
            if ($Organization) {
                $action += " into organization $Organization"
            }

            if ($ForkName) {
                $action += " as $(Hide-UrlCredential -Text $ForkName)"
            }

            $here = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation.ProviderPath
            $effects = @()
            # gh clones only a fork of a named repository; a fork of the current one gets a remote instead.
            if ($Clone -and $target.Count -gt 0) {
                $effects += "cloning it into a new folder in $here"
            }

            if ($Remote -and $RemoteName) {
                $effects += "adding it as remote $(Hide-UrlCredential -Text $RemoteName) of $here"
            }
            elseif ($Remote) {
                $effects += "adding it as remote origin of $here, renaming an existing origin to upstream"
            }

            if ($effects.Count -gt 0) {
                $action += ", $($effects -join ' and ')"
            }

            $shown = Format-GitHubTarget -Repository "$target"
            if (-not $PSCmdlet.ShouldProcess($shown, $action)) {
                return
            }

            $out = Invoke-GitHubCommand -Activity $activity -Arguments $arguments
            $urls = @($out | Where-Object { $_ -match '^https?://' })
            if ($urls.Count -eq 0) {
                return
            }

            return $urls[0]
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
