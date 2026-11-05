function Assert-GitHubNotOption {
    <#
    .SYNOPSIS
        Throws when a value starts with a dash, and returns $true otherwise.
    .DESCRIPTION
        Not exported. Run from the ValidateScript of a parameter whose value
        gh takes as an operand - an owner, a repository name - since gh
        would read one starting with a dash as an option. A ValidatePattern
        would refuse it the same way, but could not hide a credential, so
        the value is shown through Hide-UrlCredential.
    .PARAMETER Value
        The value to check.
    .OUTPUTS
        $true, when the value passes.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    if ($Value.StartsWith('-', [StringComparison]::Ordinal)) {
        throw "'$(Hide-UrlCredential -Text $Value)' starts with '-', which gh would read as an option."
    }

    return $true
}
