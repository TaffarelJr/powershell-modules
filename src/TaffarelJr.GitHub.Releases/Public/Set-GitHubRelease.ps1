function Set-GitHubRelease {
    <#
    .SYNOPSIS
        Changes a release's title, notes, tag, target, or draft,
        pre-release, and latest flags.
    .DESCRIPTION
        -Draft:$false is how a draft gets published. Each flag is a
        three-state toggle: omitted leaves it alone, given turns it on,
        and given as $false turns it off. Notes given as -Notes reach gh
        through a temporary file, so they arrive exactly as given; -Notes
        '' clears them, as -Title '' clears the title.

        -Notes and -NotesFile cannot be given together - gh would use the
        file and drop the text without saying so - so given both, the call
        throws before gh runs, as does a call that asks for no change at
        all.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Tag
        The release's current tag, or a release object, read by its
        TagName and Repository. Tags and releases can be piped in; a
        release from Get-GitHubRelease is edited in the repository it was
        read from.
    .PARAMETER Title
        The new title; an empty one clears it.
    .PARAMETER Notes
        The new release notes, as Markdown; an empty string clears them.
    .PARAMETER NotesFile
        A file to read the new release notes from, relative to the current
        location. A lone '-' is refused: gh would read standard input.
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
        With -NewTag, fails if that tag does not already exist on GitHub.
        Without -NewTag there is nothing for it to check, so it throws.
    .PARAMETER DiscussionCategory
        Starts a discussion in this category when publishing a draft; a
        blank one throws.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form, as a URL, or as a
        repository object. Omit it to use the current directory's
        repository, or the piped release's own; given as $null, it throws.
        A release in a different repository than this throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object
        A release's tag, or a release object, bound to -Tag. A piped
        release's Repository binds to -Repository.
    .OUTPUTS
        System.String
        The release's URL.
    .EXAMPLE
        Set-GitHubRelease -Tag 'v1.2.0' -Draft:$false

        Publishes the draft release tagged v1.2.0 of the current
        directory's repository, and returns its URL.
    .EXAMPLE
        Get-GitHubRelease -List -Limit 1000 -Repository OWNER/REPO |
            Where-Object IsDraft |
            Set-GitHubRelease -Draft:$false

        Publishes every draft release of OWNER/REPO, among its latest 1000.
        Without -Limit, gh lists only its default 30.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Releases/README.md
    .LINK
        Get-GitHubRelease
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [Alias('TagName')]
        [object]$Tag,

        [string]$Title,

        [string]$Notes,

        [ValidatePattern('\S', ErrorMessage = '-NotesFile is blank: give the path of a file, or leave it out.')]
        [string]$NotesFile,

        [ValidatePattern('\S', ErrorMessage = "-NewTag is blank: give the new tag's name, or leave it out.")]
        [string]$NewTag,

        [ValidatePattern('\S', ErrorMessage = '-Target is blank: give a branch name or a commit SHA, or leave it out.')]
        [string]$Target,

        [switch]$Draft,

        [switch]$Prerelease,

        [switch]$Latest,

        [switch]$VerifyTag,

        [string]$DiscussionCategory,

        [Parameter(ValueFromPipelineByPropertyName)]
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

            $given =$PSBoundParameters.ContainsKey('Repository')
            Resolve-GitHubRepositoryArgument -Value $Repository -Given $given | Out-Null
            if ($PSBoundParameters.ContainsKey('Notes') -and $PSBoundParameters.ContainsKey('NotesFile')) {
                throw '-Notes and -NotesFile cannot be used together: gh would use the file and drop the text' +
                ' without saying so. Give only one.'
            }

            if ($VerifyTag -and -not $PSBoundParameters.ContainsKey('NewTag')) {
                throw '-VerifyTag works only with -NewTag: it checks that the tag -NewTag names exists.' +
                ' Give -NewTag too, or leave -VerifyTag off.'
            }

            $category = $PSBoundParameters.ContainsKey('DiscussionCategory')
            if ($category -and [string]::IsNullOrWhiteSpace($DiscussionCategory)) {
                throw '-DiscussionCategory is blank: give a discussion category, or leave it out.'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $options = @('release', 'edit')
            if ($PSBoundParameters.ContainsKey('Title')) {
                $options += "--title=$Title"
            }

            if ($PSBoundParameters.ContainsKey('NewTag')) {
                $options += "--tag=$NewTag"
            }

            if ($PSBoundParameters.ContainsKey('Target')) {
                $options += "--target=$Target"
            }

            $toggles = [ordered]@{
                Draft      = '--draft'
                Prerelease = '--prerelease'
                Latest     = '--latest'
            }
            foreach ($name in $toggles.Keys) {
                if ($PSBoundParameters.ContainsKey($name)) {
                    $state = ([bool]$PSBoundParameters[$name]).ToString().ToLowerInvariant()
                    $options += "$($toggles[$name])=$state"
                }
            }

            if ($VerifyTag) {
                $options += '--verify-tag'
            }

            if ($PSBoundParameters.ContainsKey('DiscussionCategory')) {
                $options += "--discussion-category=$DiscussionCategory"
            }

            if ($PSBoundParameters.ContainsKey('NotesFile')) {
                $options += @('--notes-file', (Resolve-GitHubInputFile -Path $NotesFile -Name 'NotesFile'))
            }

            $hasNotes = $PSBoundParameters.ContainsKey('Notes')
            if ($options.Count -eq 2 -and -not $hasNotes) {
                throw 'Say what to change - for example -Title, -Notes, -NewTag, or -Draft.'
            }

            $reference = ConvertTo-GitHubReleaseReference -Release $Tag -Repository $Repository -PipelineBound
            $subject = Format-GitHubReleaseTarget -Tag $reference.Tag -Repository $reference.Repository
            if (-not $PSCmdlet.ShouldProcess($subject, 'Edit release')) {
                return
            }

            $change = @{
                Activity   = "Editing release $($reference.Tag)"
                Option     = $options
                Operand    = $reference.Tag
                Repository = $reference.Repository
            }
            if ($hasNotes) {
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
}
