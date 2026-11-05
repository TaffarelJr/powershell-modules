function Get-GitHubCache {
    <#
    .SYNOPSIS
        Returns a repository's GitHub Actions caches.
    .DESCRIPTION
        Runs gh cache list and returns one object per cache, narrowed by
        -Key and -Ref and ordered by -Sort. Without -Limit, gh returns its
        default 30. Pipe a cache to Remove-GitHubCache to delete it by its
        Id.
    .PARAMETER Key
        Returns only caches whose key starts with this prefix. A blank
        value is refused.
    .PARAMETER Ref
        Returns only caches for this ref, formatted as
        refs/heads/<branch> or refs/pull/<number>/merge. A blank value is
        refused.
    .PARAMETER Sort
        Orders by created_at, last_accessed_at, or size_in_bytes, in any
        casing. gh's default is last_accessed_at.
    .PARAMETER Order
        Ascending (asc) or descending (desc, gh's default), in any casing.
    .PARAMETER Limit
        The most caches to return, at least 1. gh's default is 30.
    .PARAMETER Repository
        The repository to read, as [HOST/]OWNER/REPO, a URL, or a
        repository object. Omit it to use the current directory's
        repository; a -Repository given as $null throws.
    .INPUTS
        None
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object per cache - Id, Key, Ref, Version, SizeInBytes,
        CreatedAt, LastAccessedAt, and Repository, the repository it was
        read from, written OWNER/REPO (HOST/OWNER/REPO off github.com)
        however it was named, or $null for the current directory's.
    .EXAMPLE
        Get-GitHubCache -Key 'npm-' -Sort size_in_bytes -Order desc `
            -Limit 5 -Repository 'OWNER/REPO'

        Lists the five largest caches whose key starts with npm-.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Workflows/README.md
    .LINK
        Remove-GitHubCache
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSCustomObject])]
    param(
        [string]$Key,

        [string]$Ref,

        [ValidateSet('created_at', 'last_accessed_at', 'size_in_bytes')]
        [string]$Sort,

        [ValidateSet('asc', 'desc')]
        [string]$Order,

        [ValidateRange(1, [int]::MaxValue)]
        [int]$Limit,

        [object]$Repository
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        Assert-GitHubFilterNotBlank -BoundParameters $PSBoundParameters -Name 'Key', 'Ref'
        $repositoryReference = Resolve-GitHubRepositoryArgument -Value $Repository `
            -Given $PSBoundParameters.ContainsKey('Repository')
        $arguments = @('cache', 'list', '--json', 'createdAt,id,key,lastAccessedAt,ref,sizeInBytes,version')
        if ($Key) {
            $arguments += "--key=$Key"
        }

        if ($Ref) {
            $arguments += "--ref=$Ref"
        }

        if ($Sort) {
            $arguments += @('--sort', $Sort.ToLowerInvariant())
        }

        if ($Order) {
            $arguments += @('--order', $Order.ToLowerInvariant())
        }

        if ($PSBoundParameters.ContainsKey('Limit')) {
            $arguments += @('--limit', $Limit)
        }

        $out = Invoke-GitHubCommand -Activity 'Listing caches' -Arguments $arguments -Repository $repositoryReference
        $items = ConvertFrom-GitHubJson -Lines $out
        $origin = $null
        if ($repositoryReference) {
            $origin = Format-GitHubRepositoryName -Repository $repositoryReference
        }

        foreach ($item in $items) {
            $item | Add-Member -NotePropertyName 'Repository' -NotePropertyValue $origin
            $item
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
        )
    }
}
