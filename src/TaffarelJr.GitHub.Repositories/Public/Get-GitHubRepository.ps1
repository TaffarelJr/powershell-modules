function Get-GitHubRepository {
    <#
    .SYNOPSIS
        Returns one repository, or lists the repositories an owner has.
    .DESCRIPTION
        Without -List, one repository is described: the one named, or the
        current directory's. With -List, every repository of -Owner (or
        of the authenticated user) is returned, narrowed by the filters.
    .PARAMETER Repository
        The repository to describe, in [HOST/]OWNER/REPO form or as a URL,
        or a repository object such as one a listing returned. Omit it to
        use the current directory's repository.
        A -Repository given as $null throws.
    .PARAMETER List
        Lists repositories instead of describing one.
    .PARAMETER Owner
        The user or organization whose repositories to list. Omit it for
        the authenticated user's own; a blank one is refused.
    .PARAMETER Limit
        The most repositories to list, at least 1. gh's default is 30.
    .PARAMETER Visibility
        Lists only public, private, or internal repositories.
    .PARAMETER Language
        Lists only repositories whose primary language is this. A blank one
        is refused, as it would filter nothing.
    .PARAMETER Topic
        Lists only repositories carrying every one of these topics. A blank
        one is refused, as it would filter nothing.
    .PARAMETER Fork
        Lists only forks, as gh's --fork. Refuses -Source.
    .PARAMETER Source
        Lists only non-forks, as gh's --source. Refuses -Fork.
    .PARAMETER Archived
        Lists only archived repositories, or with -Archived:$false leaves
        archived repositories out.
    .INPUTS
        System.Object
        A repository - OWNER/REPO text, a URL, or a repository object such
        as one a listing returned - for the View parameter set.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object per repository with Name, NameWithOwner, Owner,
        Description, Url, SshUrl, Visibility, IsPrivate, IsFork,
        IsArchived, IsTemplate, DefaultBranchRef, Parent, LicenseInfo,
        RepositoryTopics, the merge and feature settings, and the
        timestamps - a fixed set of fields. A single object without -List;
        one per repository with it.
    .EXAMPLE
        Get-GitHubRepository -Repository 'OWNER/REPO'

        Describes OWNER/REPO.
    .EXAMPLE
        Get-GitHubRepository -List -Owner 'OWNER' -Visibility public `
            -Limit 100

        Lists up to 100 of OWNER's public repositories.
    .EXAMPLE
        'OWNER/REPO' | Get-GitHubRepository

        Describes the repository named on the pipeline.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Set-GitHubRepository
    .LINK
        New-GitHubRepository
    #>
    [CmdletBinding(DefaultParameterSetName = 'View')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Position = 0, ParameterSetName = 'View', ValueFromPipeline)]
        [object]$Repository,

        [Parameter(Mandatory, ParameterSetName = 'List')]
        [switch]$List,

        [Parameter(ParameterSetName = 'List')]
        [ValidateScript({ Assert-GitHubNotOption -Value $_ })]
        [string]$Owner,

        [Parameter(ParameterSetName = 'List')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Limit,

        [Parameter(ParameterSetName = 'List')]
        [ValidateSet('public', 'private', 'internal')]
        [string]$Visibility,

        [Parameter(ParameterSetName = 'List')]
        [string]$Language,

        [Parameter(ParameterSetName = 'List')]
        [AllowNull()]
        [string[]]$Topic,

        [Parameter(ParameterSetName = 'List')]
        [switch]$Fork,

        [Parameter(ParameterSetName = 'List')]
        [switch]$Source,

        [Parameter(ParameterSetName = 'List')]
        [switch]$Archived
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            if ($PSBoundParameters.ContainsKey('Owner') -and [string]::IsNullOrWhiteSpace($Owner)) {
                throw '-Owner was given but is blank, so it would list your own repositories. Give a value, or' +
                ' leave -Owner off.'
            }

            if ($PSBoundParameters.ContainsKey('Language') -and [string]::IsNullOrWhiteSpace($Language)) {
                throw '-Language was given but is blank, so it would filter nothing. Give a value, or leave' +
                ' -Language off.'
            }

            $nullTopics = @($Topic | Where-Object { [string]::IsNullOrWhiteSpace($_) })
            if ($PSBoundParameters.ContainsKey('Topic') -and ($null -eq $Topic -or $nullTopics.Count -gt 0)) {
                throw '-Topic holds a blank topic, which would filter nothing. Give a value, or leave -Topic off.'
            }

            if ($PSBoundParameters.ContainsKey('Topic') -and $null -ne $Topic -and $Topic.Count -eq 0) {
                throw '-Topic was given no topics, so it would filter nothing. Give a value, or leave -Topic off.'
            }

            if ($Fork -and $Source) {
                throw '-Fork and -Source cannot be used together: -Fork lists only forks, and -Source only non-forks.' +
                ' Give only one.'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $fields = 'createdAt,defaultBranchRef,deleteBranchOnMerge,description,forkCount,hasDiscussionsEnabled,' +
            'hasIssuesEnabled,hasProjectsEnabled,hasWikiEnabled,homepageUrl,isArchived,isEmpty,isFork,isPrivate,' +
            'isTemplate,licenseInfo,mergeCommitAllowed,name,nameWithOwner,owner,parent,primaryLanguage,pushedAt,' +
            'rebaseMergeAllowed,repositoryTopics,squashMergeAllowed,sshUrl,stargazerCount,updatedAt,url,visibility'

            if (-not $List) {
                $given = $PSBoundParameters.ContainsKey('Repository')
                $reference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
                $arguments = @('repo', 'view') + @($reference) + @('--json', $fields)
                $activity = "Reading repository $reference"
                if (-not $reference) {
                    $activity = "Reading the current directory's repository"
                }

                $out = Invoke-GitHubCommand -Activity $activity -Arguments $arguments
                return ConvertFrom-GitHubJson -Lines $out
            }

            $arguments = @('repo', 'list')
            if ($Owner) {
                $arguments += $Owner
            }

            $arguments += @('--json', $fields)
            if ($PSBoundParameters.ContainsKey('Limit')) {
                $arguments += @('--limit', $Limit)
            }

            if ($Visibility) {
                $arguments += @('--visibility', $Visibility.ToLowerInvariant())
            }

            if ($Language) {
                $arguments += "--language=$Language"
            }

            foreach ($name in $Topic) {
                $arguments += "--topic=$name"
            }

            if ($Fork) {
                $arguments += '--fork'
            }

            if ($Source) {
                $arguments += '--source'
            }

            if ($PSBoundParameters.ContainsKey('Archived')) {
                $arguments += if ($Archived) { '--archived' } else { '--no-archived' }
            }

            $out = Invoke-GitHubCommand -Activity 'Listing repositories' -Arguments $arguments
            return ConvertFrom-GitHubJson -Lines $out
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
