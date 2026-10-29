function Remove-GitHubCache {
    <#
    .SYNOPSIS
        Deletes caches by id or key, or every cache in a repository.
    .DESCRIPTION
        Deletes without asking by default; -Confirm asks first. A cache
        object piped in from Get-GitHubCache is deleted by its Id.

        An id deletes that one cache. A key deletes every cache with that
        key, on every ref. gh reads a value that is all digits as an id,
        so a cache whose key is all digits cannot be deleted by its key:
        give its Id.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Id
        The caches to delete, each by id or key, or cache objects - a
        whole Get-GitHubCache listing too. An object is read only when it
        has both an Id and a Key, as a cache does, so a workflow or run
        piped in by mistake is refused rather than deleting whichever
        cache shares its number.
    .PARAMETER All
        Deletes every cache instead (gh's --all). Given with caches piped
        in, it throws rather than deleting everything once per cache.
    .PARAMETER Ref
        With -All, deletes only caches for this ref, formatted as
        refs/heads/<branch> or refs/pull/<number>/merge. A blank value is
        refused. Needs gh 2.86 or later.
    .PARAMETER SucceedOnNoCaches
        With -All, reports success even when there were no caches to
        delete. Needs gh 2.68 or later.
    .PARAMETER Repository
        The repository, as [HOST/]OWNER/REPO, a URL, or a repository
        object. A cache object is deleted where it came from - its
        Repository - and a -Repository that names another repository
        throws. Omit both to use the current directory's repository; a
        -Repository given as $null throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object
        A cache id or key, or a cache object such as Get-GitHubCache
        returns. Binds to -Id; a Repository property, when the object has
        one, binds to -Repository.
    .OUTPUTS
        None
    .EXAMPLE
        Remove-GitHubCache -Id 5000000001 -Repository 'OWNER/REPO'

        Deletes cache 5000000001 of OWNER/REPO.
    .EXAMPLE
        Get-GitHubCache -Key 'npm-' -Repository 'OWNER/REPO' |
            Remove-GitHubCache

        Deletes every cache whose key starts with npm-.
    .EXAMPLE
        Remove-GitHubCache -All -Ref 'refs/heads/feature/x' `
            -Repository 'OWNER/REPO'

        Deletes every cache of the feature/x branch.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Workflows/README.md
    .LINK
        Get-GitHubCache
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Id')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Id', ValueFromPipeline)]
        [object[]]$Id,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch]$All,

        [Parameter(ParameterSetName = 'All')]
        [string]$Ref,

        [Parameter(ParameterSetName = 'All')]
        [switch]$SucceedOnNoCaches,

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

            Resolve-GitHubRepositoryArgument -Value $Repository -Given $PSBoundParameters.ContainsKey('Repository') |
                Out-Null
            Assert-GitHubFilterNotBlank -BoundParameters $PSBoundParameters -Name 'Ref'
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            if ($All) {
                if ($MyInvocation.ExpectingInput) {
                    throw '-All deletes every cache at once: pipe caches without -All, or give -All alone.'
                }

                $arguments = @('cache', 'delete', '--all')
                if ($Ref) {
                    $arguments += "--ref=$Ref"
                }

                if ($SucceedOnNoCaches) {
                    $arguments += '--succeed-on-no-caches'
                }

                $activity = 'Deleting every cache'
                $repositoryReference = ConvertTo-GitHubRepositoryReference -Repository $Repository
                $where = Format-GitHubItemTarget -Repository $repositoryReference
                $shownRef = Hide-UrlCredential -Text $Ref
                $action = if ($Ref) { "Delete every cache for $shownRef" } else { 'Delete every cache' }
                if (-not $PSCmdlet.ShouldProcess($where, $action)) {
                    return
                }

                Invoke-GitHubCommand -Activity $activity -Arguments $arguments `
                    -Repository $repositoryReference | Out-Null
                return
            }

            $targets = foreach ($cache in $Id) {
                $reference = ConvertTo-GitHubCacheReference -Cache $cache
                $origin = Resolve-GitHubOriginRepository -Repository $Repository -InputObject $cache `
                    -Item "Cache $reference"
                [PSCustomObject]@{
                    Reference  = $reference
                    Repository = $origin
                }
            }

            foreach ($target in $targets) {
                # gh reads a reference of digits alone as an id; anything else is a key, on every ref.
                if ($target.Reference -match '^[0-9]+$') {
                    $item = "cache $($target.Reference)"
                    $action = 'Delete cache'
                }
                else {
                    $item = "cache key $($target.Reference)"
                    $action = 'Delete every cache with this key, on every ref'
                }

                $subject = Format-GitHubItemTarget -Repository $target.Repository -Item $item
                if (-not $PSCmdlet.ShouldProcess($subject, $action)) {
                    continue
                }

                $arguments = @('cache', 'delete', '--', $target.Reference)
                $activity = "Deleting cache $($target.Reference)"
                Invoke-GitHubCommand -Activity $activity -Arguments $arguments -Repository $target.Repository | Out-Null
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
