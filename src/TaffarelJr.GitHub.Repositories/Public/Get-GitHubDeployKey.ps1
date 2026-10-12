function Get-GitHubDeployKey {
    <#
    .SYNOPSIS
        Returns a repository's deploy keys.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form. Omit it to use
        the current directory's repository.
    .OUTPUTS
        One object per key - Id, Title, Key, ReadOnly, CreatedAt - always
        an array.
    #>
    param(
        [string]$Repository
    )

    $arguments = @('repo', 'deploy-key', 'list', '--json', 'createdAt,id,key,readOnly,title')
    $out = Invoke-GitHubCommand -Activity 'Listing deploy keys' -Arguments $arguments -Repository $Repository
    $keys = ConvertFrom-GitHubJson -Lines $out
    return , @($keys)
}
