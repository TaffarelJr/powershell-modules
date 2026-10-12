function Get-GitHubCache {
    <#
    .SYNOPSIS
        Returns a repository's GitHub Actions caches.
    .PARAMETER Key
        Returns only caches whose key starts with this prefix.
    .PARAMETER Ref
        Returns only caches for this ref, formatted as
        refs/heads/<branch> or refs/pull/<number>/merge.
    .PARAMETER Sort
        Orders by created_at, last_accessed_at, or size_in_bytes. gh's
        default is last_accessed_at.
    .PARAMETER Order
        Ascending (asc) or descending (desc, gh's default).
    .PARAMETER Limit
        The most caches to return. gh's default is 30.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form. Omit it to use
        the current directory's repository.
    .OUTPUTS
        One object per cache - Id, Key, Ref, Version, SizeInBytes,
        CreatedAt, LastAccessedAt - always an array.
    #>
    param(
        [string]$Key,

        [string]$Ref,

        [ValidateSet('created_at', 'last_accessed_at', 'size_in_bytes')]
        [string]$Sort,

        [ValidateSet('asc', 'desc')]
        [string]$Order,

        [int]$Limit,

        [string]$Repository
    )

    $arguments = @('cache', 'list', '--json', 'createdAt,id,key,lastAccessedAt,ref,sizeInBytes,version')
    if ($Key) {
        $arguments += @('--key', $Key)
    }

    if ($Ref) {
        $arguments += @('--ref', $Ref)
    }

    if ($Sort) {
        $arguments += @('--sort', $Sort)
    }

    if ($Order) {
        $arguments += @('--order', $Order)
    }

    if ($Limit -gt 0) {
        $arguments += @('--limit', $Limit)
    }

    $out = Invoke-GitHubCommand -Activity 'Listing caches' -Arguments $arguments -Repository $Repository
    $caches = ConvertFrom-GitHubJson -Lines $out
    return , @($caches)
}
