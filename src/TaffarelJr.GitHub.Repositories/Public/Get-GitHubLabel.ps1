function Get-GitHubLabel {
    <#
    .SYNOPSIS
        Returns a repository's labels.
    .DESCRIPTION
        Each label carries its Url, which names its repository, so
        Set-GitHubLabel and Remove-GitHubLabel act on a piped label in the
        repository it was listed from.
    .PARAMETER Search
        Returns only labels whose name or description matches, best match
        first. A blank one is refused, as it would filter nothing.
    .PARAMETER Sort
        Orders by created or name. gh's default is created.
    .PARAMETER Order
        Ascending (asc, gh's default) or descending (desc).
    .PARAMETER Limit
        The most labels to return, at least 1. gh's default is 30.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form or as a URL, or a
        repository object such as one a listing returned. Omit it to use
        the current directory's repository.
        A -Repository given as $null throws.
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object per label - Id, Name, Description, Color, IsDefault,
        Url, CreatedAt, UpdatedAt.
    .EXAMPLE
        Get-GitHubLabel -Repository 'OWNER/REPO' -Search 'bug'

        Lists the labels of OWNER/REPO whose name or description matches
        bug, best match first.
    .EXAMPLE
        Get-GitHubLabel -Sort name -Limit 100

        Lists up to 100 labels of the current directory's repository,
        ordered by name.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        New-GitHubLabel
    .LINK
        Set-GitHubLabel
    .LINK
        Remove-GitHubLabel
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSCustomObject])]
    param(
        [string]$Search,

        [ValidateSet('created', 'name')]
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

        if ($PSBoundParameters.ContainsKey('Search') -and [string]::IsNullOrWhiteSpace($Search)) {
            throw '-Search was given but is blank, so it would filter nothing. Give a value, or leave -Search off.'
        }

        $given = $PSBoundParameters.ContainsKey('Repository')
        $reference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
        $arguments = @('label', 'list', '--json', 'color,createdAt,description,id,isDefault,name,updatedAt,url')
        if ($Search) {
            $arguments += "--search=$Search"
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

        $out = Invoke-GitHubCommand -Activity 'Listing labels' -Arguments $arguments -Repository $reference
        return ConvertFrom-GitHubJson -Lines $out
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
        )
    }
}
