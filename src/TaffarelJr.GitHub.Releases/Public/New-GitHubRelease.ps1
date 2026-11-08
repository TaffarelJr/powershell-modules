function New-GitHubRelease {
    <#
    .SYNOPSIS
        Creates a release, optionally uploading assets to it.
    .DESCRIPTION
        If the tag does not exist yet, GitHub creates it from -Target or
        the default branch; -VerifyTag refuses instead. Release notes
        given as -Notes reach gh through a temporary file, so they arrive
        exactly as given, multi-line Markdown included. Without any notes
        option, gh creates the release with an empty body rather than
        prompting.

        -Notes and -NotesFile cannot be given together - gh would use the
        file and drop the text without saying so - so given both, the call
        throws before gh runs.

        -Asset is handed to gh as it is, for gh to expand: a wildcard
        pattern names every file it matches, and '#Label' on the end gives
        the asset a display label - such a path is taken literally, never
        as a pattern. gh cuts a path at its first #, so a # anywhere in an
        -Asset, a folder name included, breaks it. -LiteralAsset names
        files exactly instead, as Add-GitHubReleaseAsset -LiteralPath does.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Tag
        The release's tag.
    .PARAMETER Title
        The release's title; a blank one throws. Omit it with -GenerateNotes
        to let GitHub generate one.
    .PARAMETER Notes
        The release notes, as Markdown.
    .PARAMETER NotesFile
        A file to read the release notes from, relative to the current
        location. A lone '-' is refused: gh would read standard input.
    .PARAMETER GenerateNotes
        Has GitHub generate the notes from the commits since the last
        release.
    .PARAMETER NotesStartTag
        With -GenerateNotes, the tag to start generating from.
    .PARAMETER NotesFromTag
        Takes the notes from the tag's annotation, or its commit message.
        gh refuses it with -GenerateNotes, -NotesStartTag, or a repository.
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
        Starts a discussion in this category for the release; a blank one
        throws. gh refuses it for a draft.
    .PARAMETER FailOnNoCommits
        Fails if nothing has been committed since the last release. Needs
        gh 2.68 or later.
    .PARAMETER Asset
        Files to upload as release assets, as gh reads them: wildcards
        expanded, and '#Label' on the end a display label.
    .PARAMETER LiteralAsset
        Files to upload as release assets, exactly as named: no wildcards,
        no label, and resolved against the current location.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form, as a URL, or as a
        repository object. Omit it to use the current directory's
        repository; given as $null, it throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None.
    .OUTPUTS
        System.String
        The new release's URL.
    .EXAMPLE
        New-GitHubRelease -Tag 'v1.2.0' -Draft -GenerateNotes `
            -Asset './dist/*.nupkg'

        Creates a draft with generated notes and uploads every package in
        ./dist to it.
    .EXAMPLE
        $release = @{
            Tag        = 'v1.2.0'
            Title      = 'Version 1.2.0'
            Notes      = 'Bug fixes.'
            Repository = 'OWNER/REPO'
        }
        New-GitHubRelease @release

        Publishes the release in OWNER/REPO and returns its URL.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Releases/README.md
    .LINK
        Set-GitHubRelease
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('\S', ErrorMessage = "'{0}' is not a release tag: give the tag's name, such as 'v1.0.0'.")]
        [string]$Tag,

        [string]$Title,

        [string]$Notes,

        [ValidatePattern('\S', ErrorMessage = '-NotesFile is blank: give the path of a file, or leave it out.')]
        [string]$NotesFile,

        [switch]$GenerateNotes,

        [ValidatePattern('\S', ErrorMessage = '-NotesStartTag is blank: give a tag, or leave it out.')]
        [string]$NotesStartTag,

        [switch]$NotesFromTag,

        [switch]$Draft,

        [switch]$Prerelease,

        [switch]$Latest,

        [ValidatePattern('\S', ErrorMessage = '-Target is blank: give a branch name or a commit SHA, or leave it out.')]
        [string]$Target,

        [switch]$VerifyTag,

        [string]$DiscussionCategory,

        [switch]$FailOnNoCommits,

        [ValidatePattern(
            '\S',
            ErrorMessage = '-Asset holds a blank path: give the path of each file, or leave it out.'
        )]
        [string[]]$Asset,

        [ValidatePattern(
            '\S',
            ErrorMessage = '-LiteralAsset holds a blank path: give the path of each file, or leave it out.'
        )]
        [string[]]$LiteralAsset,

        [object]$Repository
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

        $given =$PSBoundParameters.ContainsKey('Repository')
        $repositoryReference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
        if ($PSBoundParameters.ContainsKey('Notes') -and $PSBoundParameters.ContainsKey('NotesFile')) {
            throw '-Notes and -NotesFile cannot be used together: gh would use the file and drop the text' +
            ' without saying so. Give only one.'
        }

        $blanks = [ordered]@{
            Title              = 'give the release a title'
            DiscussionCategory = 'give a discussion category'
        }
        foreach ($name in $blanks.PSBase.Keys) {
            if ($PSBoundParameters.ContainsKey($name) -and [string]::IsNullOrWhiteSpace($PSBoundParameters[$name])) {
                throw "-$name is blank: $($blanks[$name]), or leave it out."
            }
        }

        $options = @('release', 'create')
        if ($PSBoundParameters.ContainsKey('Title')) {
            $options += "--title=$Title"
        }

        if ($PSBoundParameters.ContainsKey('NotesFile')) {
            $options += @('--notes-file', (Resolve-GitHubInputFile -Path $NotesFile -Name 'NotesFile'))
        }

        if ($GenerateNotes) {
            $options += '--generate-notes'
        }

        if ($PSBoundParameters.ContainsKey('NotesStartTag')) {
            $options += "--notes-start-tag=$NotesStartTag"
        }

        if ($NotesFromTag) {
            $options += '--notes-from-tag'
        }

        if ($Draft) {
            $options += '--draft'
        }

        if ($Prerelease) {
            $options += '--prerelease'
        }

        if ($PSBoundParameters.ContainsKey('Latest')) {
            $options += "--latest=$($Latest.ToString().ToLowerInvariant())"
        }

        if ($PSBoundParameters.ContainsKey('Target')) {
            $options += "--target=$Target"
        }

        if ($VerifyTag) {
            $options += '--verify-tag'
        }

        if ($PSBoundParameters.ContainsKey('DiscussionCategory')) {
            $options += "--discussion-category=$DiscussionCategory"
        }

        if ($FailOnNoCommits) {
            $options += '--fail-on-no-commits'
        }

        $operands = @($Tag)
        if ($Asset) {
            $operands += $Asset
        }

        foreach ($file in $LiteralAsset) {
            $operands += ConvertTo-GitHubAssetArgument -LiteralPath $file -Name 'LiteralAsset'
        }

        $action = if ($Draft) { 'Create release as a draft' } else { 'Create release' }
        $uploads = @($Asset) + @($LiteralAsset) | Where-Object { $_ }
        if ($uploads) {
            $action += ", uploading $(@($uploads | Hide-UrlCredential) -join ', ')"
        }

        $subject = Format-GitHubReleaseTarget -Tag $Tag -Repository $repositoryReference
        if (-not $PSCmdlet.ShouldProcess($subject, $action)) {
            return
        }

        $change = @{
            Activity   = "Creating release $Tag"
            Option     = $options
            Operand    = $operands
            Repository = $repositoryReference
        }
        if ($PSBoundParameters.ContainsKey('Notes')) {
            $change['Notes'] = $Notes
        }

        return Invoke-GitHubReleaseChange @change
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
        )
    }
}
