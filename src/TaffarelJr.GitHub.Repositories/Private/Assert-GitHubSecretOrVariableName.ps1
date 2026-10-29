function Assert-GitHubSecretOrVariableName {
    <#
    .SYNOPSIS
        Throws unless a value is a secret or variable name, and returns
        $true otherwise.
    .DESCRIPTION
        Not exported. Run from the -Name ValidateScript of the functions
        that set or remove a secret or a variable: a name passes only as
        letters, digits, and underscores, not starting with a digit or with
        GITHUB_ (in any case). A ValidatePattern would refuse it the same
        way, but could not hide a credential, so the value is shown through
        Hide-UrlCredential.
    .PARAMETER Name
        The value to check.
    .PARAMETER Kind
        secret or variable, for the message.
    .OUTPUTS
        $true, when the value passes.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet('secret', 'variable')]
        [string]$Kind
    )

    if ($Name -notmatch '^(?!GITHUB_)[A-Za-z_][A-Za-z0-9_]*$') {
        $shown = Hide-UrlCredential -Text $Name
        throw "'$shown' is not a $Kind name: give letters, digits, and _, not led by a digit or GITHUB_."
    }

    return $true
}
