function Save-GitHubReleaseAsset {
    <#
    .SYNOPSIS
        Downloads a release's assets, or its source archive.
    .DESCRIPTION
        Without -Tag, the latest release is used, and gh then needs
        -Pattern or -Archive to say which files it means: without either,
        the call throws before gh runs. A relative -Destination or -Output
        is taken from the current location.

        -Pattern and -Archive, -Destination and -Output, and -Clobber and
        -SkipExisting each exclude the other: given both, the call throws
        before gh runs.

        -WhatIf and -Confirm name where the files would be written:
        -Destination, -Output, or the current location.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Tag
        The release's tag, or a release object, read by its TagName and
        Repository. Omit it for the latest release; an empty tag or $null
        throws rather than meaning the latest. Tags and releases can be
        piped in; a release from Get-GitHubRelease is downloaded from the
        repository it was read from.
    .PARAMETER Pattern
        Glob patterns, matched case-sensitively even on Windows; only
        assets matching one are downloaded. Given with no pattern at all,
        as from a filter that matched nothing, it throws rather than
        downloading every asset.
    .PARAMETER Archive
        Downloads the source code archive instead, as zip or tar.gz.
    .PARAMETER Destination
        The folder to download into. gh's default is the current
        location.
    .PARAMETER Output
        A file to write a single asset to instead. A lone dash is refused:
        it would have gh write the asset to standard output, where this
        function discards it.
    .PARAMETER Clobber
        Overwrites a file that already exists.
    .PARAMETER SkipExisting
        Leaves a file that already exists alone.
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
        None.
    .EXAMPLE
        Save-GitHubReleaseAsset -Pattern '*.nupkg'

        Downloads the packages of the latest release into the current
        location.
    .EXAMPLE
        $download = @{
            Tag         = 'v1.2.0'
            Pattern     = '*.zip'
            Destination = '~/downloads'
            Clobber     = $true
        }
        Save-GitHubReleaseAsset @download

        Downloads the release's zip files into the downloads folder under
        the user's home, overwriting files already there.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Releases/README.md
    .LINK
        Get-GitHubRelease
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [Alias('TagName')]
        [object]$Tag,

        [ValidatePattern('\S', ErrorMessage = '-Pattern holds a blank pattern: give glob patterns, or leave it out.')]
        [string[]]$Pattern,

        [ValidateSet('zip', 'tar.gz')]
        [string]$Archive,

        [ValidatePattern('\S', ErrorMessage = '-Destination is blank: give a folder, or leave it out.')]
        [string]$Destination,

        [ValidatePattern(
            '^(?!-$)',
            ErrorMessage = "'-' would have gh write the asset to standard output, where it is lost - give a file name."
        )]
        [string]$Output,

        [switch]$Clobber,

        [switch]$SkipExisting,

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

            $given = $PSBoundParameters.ContainsKey('Repository')
            Resolve-GitHubRepositoryArgument -Value $Repository -Given $given | Out-Null
            if ($PSBoundParameters.ContainsKey('Pattern') -and @($Pattern).Count -eq 0) {
                throw '-Pattern was given no patterns, so every asset would be downloaded. Give a pattern, or leave' +
                ' -Pattern off.'
            }

            if ($PSBoundParameters.ContainsKey('Pattern') -and $PSBoundParameters.ContainsKey('Archive')) {
                throw '-Pattern and -Archive cannot be used together: -Pattern picks release assets, and -Archive' +
                ' downloads the source code instead. Give only one.'
            }

            if ($PSBoundParameters.ContainsKey('Destination') -and $PSBoundParameters.ContainsKey('Output')) {
                throw '-Destination and -Output cannot be used together: -Output names the one file to write,' +
                ' and -Destination a folder to write into. Give only one.'
            }

            if ($PSBoundParameters.ContainsKey('Output') -and [string]::IsNullOrWhiteSpace($Output)) {
                throw '-Output is blank: give a file name, or leave it out.'
            }

            if ($Clobber -and $SkipExisting) {
                throw '-Clobber and -SkipExisting cannot be used together: one overwrites a file that already' +
                ' exists, and the other leaves it alone. Give only one.'
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
            $tagged = $PSBoundParameters.ContainsKey('Tag')
            if (-not $tagged -and -not $PSBoundParameters.ContainsKey('Pattern') -and -not $Archive) {
                throw '-Tag was left out, which means the latest release, and gh then needs -Pattern or -Archive' +
                ' to say which files to download. Give one of them, or give -Tag.'
            }

            $repositoryReference = ConvertTo-GitHubRepositoryReference -Repository $Repository
            $arguments = @('release', 'download')
            foreach ($glob in $Pattern) {
                $arguments += "--pattern=$glob"
            }

            $files = 'every asset'
            if ($PSBoundParameters.ContainsKey('Pattern')) {
                $files = "the assets matching $(@($Pattern | Hide-UrlCredential) -join ', ')"
            }

            if ($Archive) {
                $arguments += @('--archive', $Archive.ToLowerInvariant())
                $files = "the $($Archive.ToLowerInvariant()) source archive"
            }

            $destinationPath = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation.ProviderPath
            if ($PSBoundParameters.ContainsKey('Destination')) {
                $destinationPath = Resolve-GitHubPath -Path $Destination
                $arguments += @('--dir', $destinationPath)
            }

            if ($PSBoundParameters.ContainsKey('Output')) {
                $destinationPath = Resolve-GitHubPath -Path $Output
                $arguments += @('--output', $destinationPath)
            }

            $existing = ''
            if ($Clobber) {
                $arguments += '--clobber'
                $existing = ', overwriting files that exist'
            }

            if ($SkipExisting) {
                $arguments += '--skip-existing'
                $existing = ', skipping files that exist'
            }

            $activity = 'Downloading the latest release''s assets'
            $release = 'the latest release'
            if ($repositoryReference) {
                $release += " of $(Format-GitHubRepositoryName -Repository $repositoryReference)"
            }

            if ($tagged) {
                $lookup = @{
                    Release    = $Tag
                    Repository = $repositoryReference
                }
                $reference = ConvertTo-GitHubReleaseReference @lookup -PipelineBound
                $repositoryReference = $reference.Repository
                $arguments += @('--', $reference.Tag)
                $activity = "Downloading the assets of release $($reference.Tag)"
                $release = Format-GitHubReleaseTarget -Tag $reference.Tag -Repository $reference.Repository
            }

            $shownDestination = Hide-UrlCredential -Text $destinationPath
            if (-not $PSCmdlet.ShouldProcess($shownDestination, "Download $files of $release$existing")) {
                return
            }

            Invoke-GitHubCommand -Activity $activity -Arguments $arguments -Repository $repositoryReference | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
