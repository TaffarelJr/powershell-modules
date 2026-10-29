function Set-GitHubRepository {
    <#
    .SYNOPSIS
        Changes a repository's settings, or archives and unarchives it.
    .DESCRIPTION
        Says what to change, or throws: gh refuses a call that changes
        nothing when it cannot ask. Every feature switch is a three-state
        toggle: omitted leaves the setting alone, -EnableWiki turns it on,
        and -EnableWiki:$false turns it off.

        Changing -Visibility carries consequences GitHub makes a caller
        acknowledge - lost stars and watchers, detached forks - and
        passing it here is that acknowledgement. -Visibility and -Archived
        therefore need the repository named, with -Repository or through
        the pipeline; the current directory's repository is never assumed
        for them.

        An archived repository is read-only, so -Archived:$false
        unarchives before any other change is made, and -Archived
        archives after them. Each is a call of its own: if a later one
        fails, the earlier ones stay made, and the error says so.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Repository
        The repository to change, in [HOST/]OWNER/REPO form or as a URL, or
        a repository object such as one a listing returned. Omit it to use
        the current directory's repository - except with -Visibility or
        -Archived.
        A -Repository given as $null throws.
    .PARAMETER Description
        The repository description. An empty one clears it; one of only
        spaces is refused.
    .PARAMETER Homepage
        The repository's home page URL. An empty one clears it; one of only
        spaces is refused.
    .PARAMETER DefaultBranch
        The default branch name. A blank one is refused.
    .PARAMETER Visibility
        public, private, or internal. Needs gh 2.61 or later.
    .PARAMETER AddTopic
        Topics to add. A blank one is refused.
    .PARAMETER RemoveTopic
        Topics to remove. A blank one is refused.
    .PARAMETER SquashMergeCommitMessage
        The default squash-merge commit message: default, pr-title,
        pr-title-commits, or pr-title-description. gh only takes it with
        squash-merging allowed, so squash-merging is turned on with it;
        -EnableSquashMerge:$false alongside it throws. Needs gh 2.88 or
        later.
    .PARAMETER EnableIssues
        Turns issues on or off.
    .PARAMETER EnableWiki
        Turns the wiki on or off.
    .PARAMETER EnableProjects
        Turns projects on or off.
    .PARAMETER EnableDiscussions
        Turns discussions on or off.
    .PARAMETER EnableMergeCommit
        Allows or forbids merging pull requests with a merge commit.
    .PARAMETER EnableSquashMerge
        Allows or forbids squash-merging pull requests.
    .PARAMETER EnableRebaseMerge
        Allows or forbids rebase-merging pull requests.
    .PARAMETER EnableAutoMerge
        Turns auto-merge on or off.
    .PARAMETER EnableAdvancedSecurity
        Turns advanced security on or off. Needs gh 2.65 or later.
    .PARAMETER EnableSecretScanning
        Turns secret scanning on or off. Needs gh 2.65 or later.
    .PARAMETER EnableSecretScanningPushProtection
        Turns secret scanning push protection on or off. Secret scanning
        must already be on. Needs gh 2.65 or later.
    .PARAMETER DeleteBranchOnMerge
        Deletes or keeps a head branch once its pull request merges.
    .PARAMETER AllowForking
        Allows or forbids forking an organization repository.
    .PARAMETER AllowUpdateBranch
        Allows or forbids updating a pull request branch that is behind
        its base.
    .PARAMETER Template
        Marks or unmarks the repository as a template, as gh's
        --template=true|false.
    .PARAMETER Archived
        Archives the repository, or with -Archived:$false unarchives it.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object
        The repository to change - OWNER/REPO text, a URL, or a repository
        object such as one a listing returned.
    .OUTPUTS
        None.
    .EXAMPLE
        Set-GitHubRepository -Repository 'OWNER/REPO' `
            -Description 'A short summary' -EnableWiki:$false

        Sets the description of OWNER/REPO and turns its wiki off.
    .EXAMPLE
        Get-GitHubRepository -List -Owner 'my-org' -Topic 'retired' `
            -Limit 1000 |
            Set-GitHubRepository -Archived

        Archives every repository of my-org carrying the retired topic -
        up to 1000; without -Limit, gh lists only its first 30.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Get-GitHubRepository
    .LINK
        Rename-GitHubRepository
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [object]$Repository,

        [AllowEmptyString()]
        [string]$Description,

        [AllowEmptyString()]
        [string]$Homepage,

        [string]$DefaultBranch,

        [ValidateSet('public', 'private', 'internal')]
        [string]$Visibility,

        [string[]]$AddTopic,

        [string[]]$RemoveTopic,

        [ValidateSet('default', 'pr-title', 'pr-title-commits', 'pr-title-description')]
        [string]$SquashMergeCommitMessage,

        [switch]$EnableIssues,

        [switch]$EnableWiki,

        [switch]$EnableProjects,

        [switch]$EnableDiscussions,

        [switch]$EnableMergeCommit,

        [switch]$EnableSquashMerge,

        [switch]$EnableRebaseMerge,

        [switch]$EnableAutoMerge,

        [switch]$EnableAdvancedSecurity,

        [switch]$EnableSecretScanning,

        [switch]$EnableSecretScanningPushProtection,

        [switch]$DeleteBranchOnMerge,

        [switch]$AllowForking,

        [switch]$AllowUpdateBranch,

        [switch]$Template,

        [switch]$Archived
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

            $toggles = [ordered]@{
                EnableIssues                       = '--enable-issues'
                EnableWiki                         = '--enable-wiki'
                EnableProjects                     = '--enable-projects'
                EnableDiscussions                  = '--enable-discussions'
                EnableMergeCommit                  = '--enable-merge-commit'
                EnableSquashMerge                  = '--enable-squash-merge'
                EnableRebaseMerge                  = '--enable-rebase-merge'
                EnableAutoMerge                    = '--enable-auto-merge'
                EnableAdvancedSecurity             = '--enable-advanced-security'
                EnableSecretScanning               = '--enable-secret-scanning'
                EnableSecretScanningPushProtection = '--enable-secret-scanning-push-protection'
                DeleteBranchOnMerge                = '--delete-branch-on-merge'
                AllowForking                       = '--allow-forking'
                AllowUpdateBranch                  = '--allow-update-branch'
                Template                           = '--template'
            }

            foreach ($option in 'Description', 'Homepage') {
                $text = $PSBoundParameters[$option]
                if ($PSBoundParameters.ContainsKey($option) -and $text.Length -gt 0 -and $text.Trim().Length -eq 0) {
                    throw "-$option is blank: give the text, or an empty string to clear it."
                }
            }

            if ($PSBoundParameters.ContainsKey('DefaultBranch') -and [string]::IsNullOrWhiteSpace($DefaultBranch)) {
                throw '-DefaultBranch is blank, and a repository needs a default branch.'
            }

            $topicFlags = [ordered]@{
                AddTopic    = '--add-topic'
                RemoveTopic = '--remove-topic'
            }
            foreach ($option in $topicFlags.PSBase.Keys) {
                $topics = $PSBoundParameters[$option]
                if ($PSBoundParameters.ContainsKey($option) -and $null -ne $topics -and $topics.Count -eq 0) {
                    throw "-$option was given no topics, so it would change nothing." +
                    " Give a value, or leave -$option off."
                }

                $blankTopics = @($topics | Where-Object { [string]::IsNullOrWhiteSpace($_) })
                if ($PSBoundParameters.ContainsKey($option) -and ($null -eq $topics -or $blankTopics.Count -gt 0)) {
                    throw "-$option has a blank element, which would send $($topicFlags[$option])= with nothing after" +
                    " it. Give topics, or leave -$option off."
                }
            }

            $squashOff = $PSBoundParameters.ContainsKey('EnableSquashMerge') -and -not $EnableSquashMerge
            if ($SquashMergeCommitMessage -and $squashOff) {
                throw '-SquashMergeCommitMessage and -EnableSquashMerge:$false cannot be used together: the message' +
                ' needs squash-merging allowed, which -EnableSquashMerge:$false forbids. Give only one.'
            }

            $edits = @()
            if ($PSBoundParameters.ContainsKey('Description')) {
                $edits += "--description=$Description"
            }

            if ($PSBoundParameters.ContainsKey('Homepage')) {
                $edits += "--homepage=$Homepage"
            }

            if ($DefaultBranch) {
                $edits += "--default-branch=$DefaultBranch"
            }

            if ($Visibility) {
                $edits += @('--visibility', $Visibility.ToLowerInvariant(), '--accept-visibility-change-consequences')
            }

            foreach ($topic in $AddTopic) {
                $edits += "--add-topic=$topic"
            }

            foreach ($topic in $RemoveTopic) {
                $edits += "--remove-topic=$topic"
            }

            if ($SquashMergeCommitMessage) {
                $edits += @('--squash-merge-commit-message', $SquashMergeCommitMessage.ToLowerInvariant())
                if (-not $PSBoundParameters.ContainsKey('EnableSquashMerge')) {
                    $edits += '--enable-squash-merge=true'
                }
            }

            foreach ($name in $toggles.PSBase.Keys) {
                if ($PSBoundParameters.ContainsKey($name)) {
                    $state = ([bool]$PSBoundParameters[$name]).ToString().ToLowerInvariant()
                    $edits += "$($toggles[$name])=$state"
                }
            }

            $archive = $PSBoundParameters.ContainsKey('Archived')
            if ($edits.Count -eq 0 -and -not $archive) {
                throw 'Say what to change - for example -Description, -DefaultBranch, -EnableWiki, or -Archived.'
            }

            $mustName = $archive -or $Visibility
            $steps = @()
            if ($archive -and -not $Archived) {
                $steps += 'unarchive'
            }

            if ($edits.Count -gt 0) {
                $steps += 'edit'
            }

            if ($Archived) {
                $steps += 'archive'
            }

            $phrase = $steps -join ' and '
            $action = "$($phrase.Substring(0, 1).ToUpperInvariant())$($phrase.Substring(1)) repository"
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
            if ($mustName -and $target.Count -eq 0) {
                throw '-Visibility and -Archived change a repository for good, so name the repository with' +
                ' -Repository or pipe it in - the current directory''s is not assumed.'
            }

            $subject = "repository $target"
            if ($target.Count -eq 0) {
                $subject = "the current directory's repository"
            }

            $shown = Format-GitHubTarget -Repository "$target"
            if (-not $PSCmdlet.ShouldProcess($shown, $action)) {
                return
            }

            $lead = $subject.Substring(0, 1).ToUpperInvariant() + $subject.Substring(1)
            $done = $null
            if ($archive -and -not $Archived) {
                $arguments = @('repo', 'unarchive') + $target + @('--yes')
                Invoke-GitHubCommand -Activity "Unarchiving $subject" -Arguments $arguments | Out-Null
                $done = 'unarchived'
            }

            if ($edits.Count -gt 0) {
                $arguments = @('repo', 'edit') + $target + $edits
                try {
                    Invoke-GitHubCommand -Activity "Editing $subject" -Arguments $arguments | Out-Null
                }
                catch {
                    if (-not $done) {
                        throw
                    }

                    throw "$lead was $done, but editing it failed: $($_.Exception.Message)"
                }

                $done = 'edited'
            }

            if ($Archived) {
                $arguments = @('repo', 'archive') + $target + @('--yes')
                try {
                    Invoke-GitHubCommand -Activity "Archiving $subject" -Arguments $arguments | Out-Null
                }
                catch {
                    if (-not $done) {
                        throw
                    }

                    throw "$lead was $done, but archiving it failed: $($_.Exception.Message)"
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
