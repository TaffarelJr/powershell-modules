function Remove-GitHubCache {
    <#
    .SYNOPSIS
        Deletes one cache by id or key, or every cache in a repository.
    .PARAMETER Id
        The cache to delete, by id or key.
    .PARAMETER All
        Deletes every cache instead of one.
    .PARAMETER Ref
        With -All, deletes only caches for this ref, formatted as
        refs/heads/<branch> or refs/pull/<number>/merge.
    .PARAMETER SucceedOnNoCaches
        With -All, reports success even when there were no caches to
        delete.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Id')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Id', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch]$All,

        [Parameter(ParameterSetName = 'All')]
        [string]$Ref,

        [Parameter(ParameterSetName = 'All')]
        [switch]$SucceedOnNoCaches,

        [string]$Repository
    )

    process {
        $arguments = @('cache', 'delete')
        if ($All) {
            $arguments += '--all'
            if ($Ref) {
                $arguments += @('--ref', $Ref)
            }

            if ($SucceedOnNoCaches) {
                $arguments += '--succeed-on-no-caches'
            }
        }
        else {
            $arguments += $Id
        }

        $activity = if ($All) { 'Deleting every cache' } else { "Deleting cache $Id" }
        Invoke-GitHubCommand -Activity $activity -Arguments $arguments -Repository $Repository | Out-Null
    }
}
