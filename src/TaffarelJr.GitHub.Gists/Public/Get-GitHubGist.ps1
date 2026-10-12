function Get-GitHubGist {
    <#
    .SYNOPSIS
        Returns one gist in full, or lists the authenticated user's
        gists.
    .DESCRIPTION
        gh's own gist list and view have no --json support. This calls
        GitHub's REST API directly (gists, gists/{id}), the same way
        Get-GitHubRuleset does.
    .PARAMETER Id
        The gist to describe in full, by its id or URL.
    .PARAMETER List
        Lists gist summaries instead of describing one.
    .PARAMETER All
        With -List, fetches every gist instead of just the first page.
    .OUTPUTS
        With -List: one summary object per gist - Id, Description,
        Public, Files, Url, CreatedAt, UpdatedAt - always an array.
        Without it: one full object, with each file's Content included.
    #>
    [CmdletBinding(DefaultParameterSetName = 'View')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'View', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,

        [Parameter(Mandatory, ParameterSetName = 'List')]
        [switch]$List,

        [Parameter(ParameterSetName = 'List')]
        [switch]$All
    )

    process {
        if (-not $List) {
            $id = $Id -replace '^https?://gist\.github\.com/(?:[^/]+/)?', ''
            $gist = Invoke-GitHubApi -Endpoint "gists/$id"
            return ConvertTo-PascalCaseObject -InputObject $gist
        }

        $gists = Invoke-GitHubApi -Endpoint 'gists' -Paginate:$All
        $gists = ConvertTo-PascalCaseObject -InputObject $gists
        return , @($gists)
    }
}
