function Set-GitHubRelease {
    <#
    .SYNOPSIS
        Changes a release's title, notes, tag, target, or draft,
        pre-release, and latest flags.
    .DESCRIPTION
        -Draft:$false is how a draft gets published. Each flag is a
        three-state toggle: omitted leaves it alone, given turns it on,
        and given as $false turns it off. Notes given as -Notes travel
        to gh on standard input, so multi-line Markdown arrives intact.
    .PARAMETER Tag
        The release's current tag.
    .PARAMETER Title
        The new title.
    .PARAMETER Notes
        The new release notes, as Markdown.
    .PARAMETER NotesFile
        A file to read the new release notes from.
    .PARAMETER NewTag
        A new tag name for the release.
    .PARAMETER Target
        The branch or commit SHA the tag should point at.
    .PARAMETER Draft
        Makes the release a draft, or with -Draft:$false publishes it.
    .PARAMETER Prerelease
        Marks the release a pre-release, or with -Prerelease:$false a
        full release.
    .PARAMETER Latest
        Marks the release as latest, or with -Latest:$false not.
    .PARAMETER VerifyTag
        Fails if the tag does not already exist on GitHub.
    .PARAMETER DiscussionCategory
        Starts a discussion in this category when publishing a draft.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Tag,

        [string]$Title,

        [string]$Notes,

        [string]$NotesFile,

        [string]$NewTag,

        [string]$Target,

        [switch]$Draft,

        [switch]$Prerelease,

        [switch]$Latest,

        [switch]$VerifyTag,

        [string]$DiscussionCategory,

        [string]$Repository
    )

    $arguments = @('release', 'edit', $Tag)
    if ($Title) {
        $arguments += @('--title', $Title)
    }

    if ($PSBoundParameters.ContainsKey('Notes')) {
        $arguments += @('--notes-file', '-')
    }

    if ($NotesFile) {
        $arguments += @('--notes-file', $NotesFile)
    }

    if ($NewTag) {
        $arguments += @('--tag', $NewTag)
    }

    if ($Target) {
        $arguments += @('--target', $Target)
    }

    $toggles = [ordered]@{
        Draft      = '--draft'
        Prerelease = '--prerelease'
        Latest     = '--latest'
    }
    foreach ($name in $toggles.Keys) {
        if ($PSBoundParameters.ContainsKey($name)) {
            $state = ([bool]$PSBoundParameters[$name]).ToString().ToLowerInvariant()
            $arguments += "$($toggles[$name])=$state"
        }
    }

    if ($VerifyTag) {
        $arguments += '--verify-tag'
    }

    if ($DiscussionCategory) {
        $arguments += @('--discussion-category', $DiscussionCategory)
    }

    $extra = @{}
    if ($PSBoundParameters.ContainsKey('Notes')) {
        $extra['StdIn'] = $Notes
    }

    Invoke-GitHubCommand -Activity "Editing release $Tag" -Arguments $arguments -Repository $Repository @extra | Out-Null
}
