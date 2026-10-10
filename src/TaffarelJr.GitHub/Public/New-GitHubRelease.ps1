function New-GitHubRelease {
    <#
    .SYNOPSIS
        Creates a release, optionally uploading assets to it.
    .DESCRIPTION
        If the tag does not exist yet, GitHub creates it from -Target or
        the default branch; -VerifyTag refuses instead. Release notes
        given as -Notes travel to gh on standard input, so multi-line
        Markdown arrives intact. Without any notes option, gh creates the
        release with an empty body rather than prompting.
    .PARAMETER Tag
        The release's tag.
    .PARAMETER Title
        The release's title. Omit it with -GenerateNotes to let GitHub
        generate one.
    .PARAMETER Notes
        The release notes, as Markdown.
    .PARAMETER NotesFile
        A file to read the release notes from.
    .PARAMETER GenerateNotes
        Has GitHub generate the notes from the commits since the last
        release.
    .PARAMETER NotesStartTag
        With -GenerateNotes, the tag to start generating from.
    .PARAMETER NotesFromTag
        Takes the notes from the tag's annotation, or its commit message.
    .PARAMETER Draft
        Saves the release as a draft instead of publishing it.
    .PARAMETER Prerelease
        Marks the release a pre-release.
    .PARAMETER Latest
        Marks the release as latest, or with -Latest:$false explicitly
        not. Omit it to let GitHub decide by date and version.
    .PARAMETER Target
        The branch or commit SHA to create the tag from, when the tag
        does not exist yet.
    .PARAMETER VerifyTag
        Fails if the tag does not already exist on GitHub.
    .PARAMETER DiscussionCategory
        Starts a discussion in this category for the release.
    .PARAMETER FailOnNoCommits
        Fails if nothing has been committed since the last release.
    .PARAMETER Asset
        Files to upload as release assets. Append '#Label' to a path to
        give the asset a display label.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    .OUTPUTS
        The new release's URL.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Tag,

        [string]$Title,

        [string]$Notes,

        [string]$NotesFile,

        [switch]$GenerateNotes,

        [string]$NotesStartTag,

        [switch]$NotesFromTag,

        [switch]$Draft,

        [switch]$Prerelease,

        [switch]$Latest,

        [string]$Target,

        [switch]$VerifyTag,

        [string]$DiscussionCategory,

        [switch]$FailOnNoCommits,

        [string[]]$Asset,

        [string]$Repository
    )

    $arguments = @('release', 'create', $Tag)
    if ($Asset) {
        $arguments += $Asset
    }

    if ($Title) {
        $arguments += @('--title', $Title)
    }

    if ($PSBoundParameters.ContainsKey('Notes')) {
        $arguments += @('--notes-file', '-')
    }

    if ($NotesFile) {
        $arguments += @('--notes-file', $NotesFile)
    }

    if ($GenerateNotes) {
        $arguments += '--generate-notes'
    }

    if ($NotesStartTag) {
        $arguments += @('--notes-start-tag', $NotesStartTag)
    }

    if ($NotesFromTag) {
        $arguments += '--notes-from-tag'
    }

    if ($Draft) {
        $arguments += '--draft'
    }

    if ($Prerelease) {
        $arguments += '--prerelease'
    }

    if ($PSBoundParameters.ContainsKey('Latest')) {
        $arguments += "--latest=$($Latest.ToString().ToLowerInvariant())"
    }

    if ($Target) {
        $arguments += @('--target', $Target)
    }

    if ($VerifyTag) {
        $arguments += '--verify-tag'
    }

    if ($DiscussionCategory) {
        $arguments += @('--discussion-category', $DiscussionCategory)
    }

    if ($FailOnNoCommits) {
        $arguments += '--fail-on-no-commits'
    }

    $extra = @{}
    if ($PSBoundParameters.ContainsKey('Notes')) {
        $extra['StdIn'] = $Notes
    }

    $out = Invoke-GitHubCommand -Activity "Creating release $Tag" -Arguments $arguments -Repository $Repository @extra
    return $out | Where-Object { $_ -match '^https?://' } | Select-Object -First 1
}
