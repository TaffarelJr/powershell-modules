function Sync-GitHubRepository {
    <#
    .SYNOPSIS
        Brings a repository's branch up to date with its source
        repository's.
    .DESCRIPTION
        Fast-forwards the destination's branch to match the source's -
        by default a fork from its parent. Where the branches have
        diverged, only -Force reconciles them, by hard-resetting the
        destination.

        Without -Destination, gh syncs the current directory's local
        clone, running git itself; git can then stop to ask for
        credentials or an SSH passphrase, which nothing here answers, so
        have those set up before a run nobody watches. -WhatIf and -Confirm
        then name that clone by its full path: PowerShell's current file
        system location, where gh runs.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Destination
        The repository to update, in [HOST/]OWNER/REPO form or as a URL, or
        a repository object. Omit it to update the current directory's
        local repository; $null throws rather than meaning that.
    .PARAMETER Source
        The repository to update from, gh's --source, in [HOST/]OWNER/REPO
        form or as a URL, or a repository object. Omit it for the
        destination's parent.
    .PARAMETER Branch
        The branch to sync. Omit it for the source's default branch; a
        blank one is refused.
    .PARAMETER Force
        Hard-resets the destination branch to the source's when they have
        diverged.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object
        The repository to update - OWNER/REPO text, a URL, or a repository
        object.
    .OUTPUTS
        None.
    .EXAMPLE
        Sync-GitHubRepository -Destination 'OWNER/FORK' -Branch 'main'

        Fast-forwards the main branch of OWNER/FORK to its parent's.
    .EXAMPLE
        Sync-GitHubRepository

        Fast-forwards the current directory's local repository, running
        git.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        New-GitHubFork
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [object]$Destination,

        [object]$Source,

        [string]$Branch,

        [switch]$Force
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

            if ($PSBoundParameters.ContainsKey('Branch') -and [string]::IsNullOrWhiteSpace($Branch)) {
                throw '-Branch was given but is blank, so the source''s default branch would be synced. Give a value,' +
                ' or leave -Branch off.'
            }

            $local = "the current directory's local repository"
            $sourceArgument = @{
                Value   = $Source
                Given   = $PSBoundParameters.ContainsKey('Source')
                Name    = 'Source'
                Omitted = "the destination's parent"
            }
            $from = Resolve-GitHubRepositoryArgument @sourceArgument
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $destinationArgument = @{
                Value   = $Destination
                Given   = $PSBoundParameters.ContainsKey('Destination')
                Name    = 'Destination'
                Omitted = $local
            }
            $to = @(Resolve-GitHubRepositoryArgument @destinationArgument)
            $activity = "Syncing repository $to"
            if ($to.Count -eq 0) {
                $activity = "Syncing the current directory's local repository"
            }

            $arguments = @('repo', 'sync') + $to
            if ($from) {
                $arguments += @('--source', $from)
            }

            if ($Branch) {
                $arguments += "--branch=$Branch"
            }

            if ($Force) {
                $arguments += '--force'
            }

            $shown = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation.ProviderPath
            if ($to.Count -gt 0) {
                $shown = Format-GitHubRepositoryName -Repository "$to"
            }

            $action = 'Sync the default branch'
            if ($Branch) {
                $action = "Sync branch $(Hide-UrlCredential -Text $Branch)"
            }

            if ($from) {
                $action += " from $(Format-GitHubRepositoryName -Repository $from)"
            }

            if ($Force) {
                $action += ', hard-resetting it if it has diverged'
            }

            if (-not $PSCmdlet.ShouldProcess($shown, $action)) {
                return
            }

            Invoke-GitHubCommand -Activity $activity -Arguments $arguments | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
