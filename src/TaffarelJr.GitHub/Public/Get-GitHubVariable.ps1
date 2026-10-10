function Get-GitHubVariable {
    <#
    .SYNOPSIS
        Returns one Actions variable by name, or every variable at a
        repository, environment, or organization level.
    .PARAMETER Name
        The variable to return. Omit it to list them all.
    .PARAMETER Environment
        Reads a deployment environment's variables instead of the
        repository's own.
    .PARAMETER Organization
        Reads an organization's variables instead of a repository's.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form. Omit it to use
        the current directory's repository.
    .OUTPUTS
        With -Name, one object: Name, Value, CreatedAt, UpdatedAt,
        Visibility, NumSelectedRepos, SelectedReposURL. Without, one such
        object per variable, always an array.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [string]$Environment,

        [string]$Organization,

        [string]$Repository
    )

    $fields = 'createdAt,name,numSelectedRepos,selectedReposURL,updatedAt,value,visibility'
    $arguments = if ($Name) {
        @('variable', 'get', $Name, '--json', $fields)
    }
    else {
        @('variable', 'list', '--json', $fields)
    }

    if ($Environment) {
        $arguments += @('--env', $Environment)
    }

    if ($Organization) {
        $arguments += @('--org', $Organization)
    }

    $activity = if ($Name) { "Reading variable $Name" } else { 'Listing variables' }
    $out = Invoke-GitHubCommand -Activity $activity -Arguments $arguments -Repository $Repository
    $result = ConvertFrom-GitHubJson -Lines $out
    if ($Name) {
        return $result
    }

    return , @($result)
}
