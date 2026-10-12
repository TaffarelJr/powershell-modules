function Assert-GitHubEndpoint {
    <#
    .SYNOPSIS
        Throws when an API endpoint starts with a dash, and returns $true
        otherwise.
    .DESCRIPTION
        Not exported. Run from the -Endpoint ValidateScript of
        Invoke-GitHubApi and Test-GitHubApi: gh would read such an endpoint
        as an option. The endpoint is shown with any credential hidden.
    .PARAMETER Endpoint
        The endpoint to check.
    .OUTPUTS
        $true, when the endpoint passes.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Endpoint
    )

    if ($Endpoint.StartsWith('-')) {
        throw "'$(Hide-UrlCredential -Text $Endpoint)' starts with '-', which gh would read as an option."
    }

    return $true
}
