using namespace System.Collections.Generic

function Add-GitHubReleaseAsset {
    <#
    .SYNOPSIS
        Uploads files to a release as assets.
    .DESCRIPTION
        With -Clobber, an existing asset of the same name is deleted
        before the new one uploads - and stays gone if that upload then
        fails.

        Files piped in are gathered first and uploaded in one gh call, so
        they must all be for one release: files whose records name two
        repositories throw, and so does a record that is not a file, with
        nothing uploaded at all. An empty pipeline uploads nothing.

        -Path is handed to gh as it is, for gh to expand: a wildcard
        pattern (./dist/*.nupkg) names every file it matches, and '#Label'
        on the end gives the asset a display label - such a path is taken
        literally, never as a pattern. gh cuts a path at its first #, so a
        # anywhere in a -Path, a folder name included, breaks it.

        -LiteralPath names files exactly, as PowerShell's own -LiteralPath
        does: no wildcards, and resolved here, so ~ and drives work and a
        file that is not there throws before gh runs. A # in such a path is
        avoided where it can be, by sending the path relative to the
        current location; where it cannot, the call throws, naming the
        file. Files piped in from Get-ChildItem bind to it.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Tag
        The release's tag, or a release object, read by its TagName and
        Repository - so a release from Get-GitHubRelease gets its files in
        the repository it was read from.
    .PARAMETER Path
        The files to upload, as gh reads them: wildcards expanded, and
        '#Label' on the end a display label. Paths can be piped in as text.
    .PARAMETER LiteralPath
        The files to upload, exactly as named. Files piped in from
        Get-ChildItem bind to it by their FullName.
    .PARAMETER Clobber
        Replaces an asset that already has the same name.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form, as a URL, or as a
        repository object. Omit it to use the current directory's
        repository, or the -Tag release's own; given as $null, it throws.
        A -Tag release in a different repository than this throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.String
        A path to upload, bound to -Path.
    .INPUTS
        System.IO.FileInfo
        A file, such as Get-ChildItem returns, bound to -LiteralPath by its
        FullName.
    .OUTPUTS
        None.
    .EXAMPLE
        Add-GitHubReleaseAsset -Tag 'v1.2.0' -Path './dist/*.nupkg'

        Uploads every package in ./dist to the release tagged v1.2.0 of the
        current directory's repository.
    .EXAMPLE
        Get-ChildItem -LiteralPath ./dist -Filter *.zip |
            Add-GitHubReleaseAsset -Tag 'v1.2.0' -Clobber

        Uploads every zip file in ./dist in one call, replacing assets of
        the same names, whatever characters the file names hold.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Releases/README.md
    .LINK
        Remove-GitHubReleaseAsset
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Path')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [object]$Tag,

        [Parameter(Mandatory, Position = 1, ParameterSetName = 'Path', ValueFromPipeline)]
        [ValidatePattern('\S', ErrorMessage = '-Path holds a blank path: give the path of each file, or leave it out.')]
        [string[]]$Path,

        [Parameter(Mandatory, ParameterSetName = 'LiteralPath', ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'PSPath')]
        [ValidatePattern(
            '\S',
            ErrorMessage = '-LiteralPath holds a blank path: give the path of each file, or leave it out.'
        )]
        [string[]]$LiteralPath,

        [switch]$Clobber,

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
            $release = $null
            $subject = $null
            $files = [List[string]]::new()
            $named = [List[string]]::new()
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            # A [string] parameter binds any piped object as its text, so only text is a path here.
            if ($PSCmdlet.ParameterSetName -eq 'Path' -and $MyInvocation.ExpectingInput -and $_ -isnot [string]) {
                throw "A $($_.GetType().Name) was piped in, which is not a file: pipe paths as text, or files" +
                ' from Get-ChildItem.'
            }

            $reference = ConvertTo-GitHubReleaseReference -Release $Tag -Repository $Repository
            $target = Format-GitHubReleaseTarget -Tag $reference.Tag -Repository $reference.Repository
            if ($null -eq $subject) {
                $release = $reference
                $subject = $target
            }
            elseif ($target -ne $subject) {
                throw "The files piped in are for more than one release: $subject, then $target." +
                ' Pipe the files of one release at a time.'
            }

            if ($PSCmdlet.ParameterSetName -eq 'LiteralPath') {
                $named.AddRange([string[]]$LiteralPath)
                foreach ($file in $LiteralPath) {
                    $files.Add((ConvertTo-GitHubAssetArgument -LiteralPath $file -Name 'LiteralPath'))
                }
            }
            else {
                $named.AddRange([string[]]$Path)
                $files.AddRange([string[]]$Path)
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    end {
        try {
            if ($files.Count -eq 0) {
                return
            }

            $arguments = @('release', 'upload')
            $action = "Upload $(@($named | Hide-UrlCredential) -join ', ')"
            if ($Clobber) {
                $arguments += '--clobber'
                $action += ', replacing assets of the same name'
            }

            if (-not $PSCmdlet.ShouldProcess($subject, $action)) {
                return
            }

            $arguments += @('--', $release.Tag)
            $arguments += $files.ToArray()
            $invocation = @{
                Activity   = "Uploading assets to release $($release.Tag)"
                Arguments  = $arguments
                Repository = $release.Repository
            }
            Invoke-GitHubCommand @invocation | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
