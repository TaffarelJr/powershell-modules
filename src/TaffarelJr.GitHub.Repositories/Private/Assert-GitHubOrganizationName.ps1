function Assert-GitHubOrganizationName {
    <#
    .SYNOPSIS
        Throws unless a value is an organization name, and returns $true
        otherwise.
    .DESCRIPTION
        Not exported. Run from the -Organization ValidateScript of every
        function that takes one: a value passes only as letters, digits, and
        dashes, not starting with a dash. A ValidatePattern would refuse it
        the same way, but could not hide a credential - a caller may paste a
        URL such as https://x-access-token:<token>@github.com/org here - so
        the value is shown through Hide-UrlCredential.
    .PARAMETER Name
        The value to check.
    .PARAMETER AllowBlank
        Lets an empty or blank value pass, for a caller that refuses it in a
        message of its own.
    .OUTPUTS
        $true, when the value passes.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name,

        [switch]$AllowBlank
    )

    if ($AllowBlank -and [string]::IsNullOrWhiteSpace($Name)) {
        return $true
    }

    if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9-]*$') {
        throw "'$(Hide-UrlCredential -Text $Name)' is not an organization name: give letters, digits, and dashes."
    }

    return $true
}
