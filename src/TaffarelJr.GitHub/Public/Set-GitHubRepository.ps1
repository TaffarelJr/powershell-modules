function Set-GitHubRepository {
    <#
    .SYNOPSIS
        Changes a repository's settings, or archives and unarchives it.
    .DESCRIPTION
        Every feature switch is a three-state toggle: omitted leaves the
        setting alone, -EnableWiki turns it on, and -EnableWiki:$false
        turns it off. Changing -Visibility carries consequences GitHub
        makes a caller acknowledge - lost stars and watchers, detached
        forks - and passing it here is that acknowledgement.
    .PARAMETER Repository
        The repository to change, as OWNER/REPO or a URL. Omit it to use
        the current directory's repository.
    .PARAMETER Description
        The repository description.
    .PARAMETER Homepage
        The repository's home page URL.
    .PARAMETER DefaultBranch
        The default branch name.
    .PARAMETER Visibility
        public, private, or internal.
    .PARAMETER AddTopic
        Topics to add.
    .PARAMETER RemoveTopic
        Topics to remove.
    .PARAMETER SquashMergeCommitMessage
        The default squash-merge commit message: default, pr-title,
        pr-title-commits, or pr-title-description.
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
        Turns advanced security on or off.
    .PARAMETER EnableSecretScanning
        Turns secret scanning on or off.
    .PARAMETER EnableSecretScanningPushProtection
        Turns secret scanning push protection on or off. Secret scanning
        must already be on.
    .PARAMETER DeleteBranchOnMerge
        Deletes or keeps a head branch once its pull request merges.
    .PARAMETER AllowForking
        Allows or forbids forking an organization repository.
    .PARAMETER AllowUpdateBranch
        Allows or forbids updating a pull request branch that is behind
        its base.
    .PARAMETER Template
        Marks or unmarks the repository as a template.
    .PARAMETER Archived
        Archives the repository, or with -Archived:$false unarchives it.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Repository,

        [string]$Description,

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

    $target = @()
    if ($Repository) {
        $target += $Repository
    }

    $edits = @()
    if ($Description) {
        $edits += @('--description', $Description)
    }

    if ($Homepage) {
        $edits += @('--homepage', $Homepage)
    }

    if ($DefaultBranch) {
        $edits += @('--default-branch', $DefaultBranch)
    }

    if ($Visibility) {
        $edits += @('--visibility', $Visibility, '--accept-visibility-change-consequences')
    }

    foreach ($topic in $AddTopic) {
        $edits += @('--add-topic', $topic)
    }

    foreach ($topic in $RemoveTopic) {
        $edits += @('--remove-topic', $topic)
    }

    if ($SquashMergeCommitMessage) {
        $edits += @('--squash-merge-commit-message', $SquashMergeCommitMessage)
    }

    foreach ($name in $toggles.Keys) {
        if ($PSBoundParameters.ContainsKey($name)) {
            $state = ([bool]$PSBoundParameters[$name]).ToString().ToLowerInvariant()
            $edits += "$($toggles[$name])=$state"
        }
    }

    if ($edits.Count -gt 0) {
        $arguments = @('repo', 'edit') + $target + $edits
        Invoke-GitHubCommand -Activity 'Editing the repository' -Arguments $arguments | Out-Null
    }

    if ($PSBoundParameters.ContainsKey('Archived')) {
        $subcommand = if ($Archived) { 'archive' } else { 'unarchive' }
        $arguments = @('repo', $subcommand) + $target + @('--yes')
        Invoke-GitHubCommand -Activity "Changing whether the repository is archived" -Arguments $arguments | Out-Null
    }
}
