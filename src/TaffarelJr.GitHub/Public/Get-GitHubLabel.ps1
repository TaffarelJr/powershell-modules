function Get-GitHubLabel {
    <#
    .SYNOPSIS
        Returns a repository's labels.
    .PARAMETER Search
        Returns only labels whose name or description matches, best match
        first.
    .PARAMETER Sort
        Orders by created or name. gh's default is created.
    .PARAMETER Order
        Ascending (asc, gh's default) or descending (desc).
    .PARAMETER Limit
        The most labels to return. gh's default is 30.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form. Omit it to use
        the current directory's repository.
    .OUTPUTS
        One object per label - Id, Name, Description, Color, IsDefault,
        Url, CreatedAt, UpdatedAt - always an array.
    #>
    param(
        [string]$Search,

        [ValidateSet('created', 'name')]
        [string]$Sort,

        [ValidateSet('asc', 'desc')]
        [string]$Order,

        [int]$Limit,

        [string]$Repository
    )

    $arguments = @('label', 'list', '--json', 'color,createdAt,description,id,isDefault,name,updatedAt,url')
    if ($Search) {
        $arguments += @('--search', $Search)
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

    $out = Invoke-GitHubCommand -Activity 'Listing labels' -Arguments $arguments -Repository $Repository
    $labels = ConvertFrom-GitHubJson -Lines $out
    return , @($labels)
}
