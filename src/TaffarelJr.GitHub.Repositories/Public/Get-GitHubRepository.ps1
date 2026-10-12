function Get-GitHubRepository {
    <#
    .SYNOPSIS
        Returns one repository, or lists the repositories an owner has.
    .DESCRIPTION
        Without -List, one repository is described: the one named, or the
        current directory's. With -List, every repository of -Owner (or
        of the authenticated user) is returned, narrowed by the filters.
    .PARAMETER Repository
        The repository to describe, in [HOST/]OWNER/REPO form. Omit it to
        use the current directory's repository.
    .PARAMETER List
        Lists repositories instead of describing one.
    .PARAMETER Owner
        The user or organization whose repositories to list. Omit it for
        the authenticated user's own.
    .PARAMETER Limit
        The most repositories to list. gh's default is 30.
    .PARAMETER Visibility
        Lists only public, private, or internal repositories.
    .PARAMETER Language
        Lists only repositories whose primary language is this.
    .PARAMETER Topic
        Lists only repositories carrying every one of these topics.
    .PARAMETER Fork
        Lists only forks.
    .PARAMETER Source
        Lists only non-forks.
    .PARAMETER Archived
        Lists only archived repositories.
    .PARAMETER NoArchived
        Leaves archived repositories out.
    .OUTPUTS
        One object per repository with Name, NameWithOwner, Owner,
        Description, Url, SshUrl, Visibility, IsPrivate, IsFork,
        IsArchived, IsTemplate, DefaultBranchRef, Parent, LicenseInfo,
        RepositoryTopics, the merge and feature settings, and the
        timestamps. A single object without -List; always an array with
        it.
    #>
    [CmdletBinding(DefaultParameterSetName = 'View')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'View')]
        [string]$Repository,

        [Parameter(Mandatory, ParameterSetName = 'List')]
        [switch]$List,

        [Parameter(ParameterSetName = 'List')]
        [string]$Owner,

        [Parameter(ParameterSetName = 'List')]
        [int]$Limit,

        [Parameter(ParameterSetName = 'List')]
        [ValidateSet('public', 'private', 'internal')]
        [string]$Visibility,

        [Parameter(ParameterSetName = 'List')]
        [string]$Language,

        [Parameter(ParameterSetName = 'List')]
        [string[]]$Topic,

        [Parameter(ParameterSetName = 'List')]
        [switch]$Fork,

        [Parameter(ParameterSetName = 'List')]
        [switch]$Source,

        [Parameter(ParameterSetName = 'List')]
        [switch]$Archived,

        [Parameter(ParameterSetName = 'List')]
        [switch]$NoArchived
    )

    $fields = 'createdAt,defaultBranchRef,deleteBranchOnMerge,description,forkCount,hasDiscussionsEnabled,hasIssuesEnabled,hasProjectsEnabled,hasWikiEnabled,homepageUrl,isArchived,isEmpty,isFork,isPrivate,isTemplate,licenseInfo,mergeCommitAllowed,name,nameWithOwner,owner,parent,primaryLanguage,pushedAt,rebaseMergeAllowed,repositoryTopics,squashMergeAllowed,sshUrl,stargazerCount,updatedAt,url,visibility'

    if (-not $List) {
        $arguments = @('repo', 'view')
        if ($Repository) {
            $arguments += $Repository
        }

        $arguments += @('--json', $fields)
        $out = Invoke-GitHubCommand -Activity 'Reading the repository' -Arguments $arguments
        return ConvertFrom-GitHubJson -Lines $out
    }

    $arguments = @('repo', 'list')
    if ($Owner) {
        $arguments += $Owner
    }

    $arguments += @('--json', $fields)
    if ($Limit -gt 0) {
        $arguments += @('--limit', $Limit)
    }

    if ($Visibility) {
        $arguments += @('--visibility', $Visibility)
    }

    if ($Language) {
        $arguments += @('--language', $Language)
    }

    foreach ($name in $Topic) {
        $arguments += @('--topic', $name)
    }

    if ($Fork) {
        $arguments += '--fork'
    }

    if ($Source) {
        $arguments += '--source'
    }

    if ($Archived) {
        $arguments += '--archived'
    }

    if ($NoArchived) {
        $arguments += '--no-archived'
    }

    $out = Invoke-GitHubCommand -Activity 'Listing repositories' -Arguments $arguments
    $repositories = ConvertFrom-GitHubJson -Lines $out
    return , @($repositories)
}
