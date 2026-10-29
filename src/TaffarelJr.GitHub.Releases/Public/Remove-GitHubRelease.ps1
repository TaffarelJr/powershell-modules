function Remove-GitHubRelease {
    <#
    .SYNOPSIS
        Deletes a release, and optionally its tag.
    .DESCRIPTION
        Deletes without asking by default; -Confirm asks first. In a
        repository with immutable releases, a published release can still
        be deleted, but its tag name can never be used for a release there
        again.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Tag
        The release's tag, or a release object, read by its TagName and
        Repository. Tags and releases can be piped in; a release from
        Get-GitHubRelease is deleted in the repository it was read from.
    .PARAMETER CleanupTag
        Deletes the git tag as well as the release.
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
        Remove-GitHubRelease -Tag 'v1.2.0' -CleanupTag -Repository OWNER/REPO

        Deletes the release tagged v1.2.0 of OWNER/REPO, and its tag.
    .EXAMPLE
        Get-GitHubRelease -List -Limit 1000 -Repository OWNER/REPO |
            Where-Object IsDraft |
            Remove-GitHubRelease

        Deletes every draft release of OWNER/REPO, among its latest 1000.
        Without -Limit, gh lists only its default 30.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Releases/README.md
    .LINK
        Get-GitHubRelease
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [Alias('TagName')]
        [object]$Tag,

        [switch]$CleanupTag,

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
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $reference = ConvertTo-GitHubReleaseReference -Release $Tag -Repository $Repository -PipelineBound
            $arguments = @('release', 'delete', '--yes')
            $action = 'Delete release'
            if ($CleanupTag) {
                $arguments += '--cleanup-tag'
                $action = 'Delete release and its tag'
            }

            $subject = Format-GitHubReleaseTarget -Tag $reference.Tag -Repository $reference.Repository
            if (-not $PSCmdlet.ShouldProcess($subject, $action)) {
                return
            }

            $arguments += @('--', $reference.Tag)
            $invocation = @{
                Activity   = "Deleting release $($reference.Tag)"
                Arguments  = $arguments
                Repository = $reference.Repository
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
