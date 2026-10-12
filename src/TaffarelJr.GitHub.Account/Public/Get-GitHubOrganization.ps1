function Get-GitHubOrganization {
    <#
    .SYNOPSIS
        Returns the organizations the authenticated user belongs to.
    .DESCRIPTION
        gh's own org list has no --json support. This calls GitHub's REST
        API directly (user/orgs), the same way Get-GitHubRuleset does.
    .PARAMETER All
        Fetches every organization instead of just the first page.
    .OUTPUTS
        One object per organization - Login, Id, Description, Url -
        always an array.
    #>
    param(
        [switch]$All
    )

    $organizations = Invoke-GitHubApi -Endpoint 'user/orgs' -Paginate:$All
    $organizations = ConvertTo-PascalCaseObject -InputObject $organizations
    return , @($organizations)
}
