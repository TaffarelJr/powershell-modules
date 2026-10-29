function Assert-GitHubAccountName {
    <#
    .SYNOPSIS
        Throws unless a -User value is one gh can read as an account, and
        returns $true otherwise.
    .DESCRIPTION
        Not exported - the one check behind every -User in this module,
        run from each parameter's ValidateScript, which needs $true back.
        Host names go through Assert-GitHubHostname from
        TaffarelJr.GitHub.Core.

        A login is one word: whitespace (zero-width characters included),
        a slash, a backslash, a colon, @, ?, #, or * would make gh look up
        an account no host can hold, and a leading dash would make gh read
        it as a flag. An empty value is refused too: a lookup that came
        back with nothing must not mean the active account.
    .PARAMETER User
        An account name to check.
    .OUTPUTS
        $true, when the value passes.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$User
    )

    if ($User -notmatch '^(?!-)[^\s\p{Cf}/\\:@?#*]+\z') {
        $shown = Hide-UrlCredential -Text $User
        throw "'$shown' is not an account name: give the login alone, such as octocat, with no space, slash," +
        ' colon, @, ?, #, *, or leading dash - or leave -User out for the active account.'
    }

    return $true
}
