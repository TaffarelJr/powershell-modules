function Hide-GitHubCredential {
    <#
    .SYNOPSIS
        Returns the text with every credential in it hidden: the user
        information a URL carries, and a GitHub token that stands alone.
    .DESCRIPTION
        Not exported. What a message shows of gh's own words - the activity,
        an argument, a line gh printed - goes through here.
        Hide-UrlCredential hides what a URL carries; this also hides a token
        printed on its own, as gh does with --show-token, or as an error
        quotes it. GitHub's token forms are ghp_, gho_, ghu_, ghs_ and ghr_
        followed by letters and digits, and github_pat_ followed by letters,
        digits and underscores. Any other secret that is not part of a URL is
        shown as it is.

        The text is taken as an argument or from the pipeline, one string at a
        time, as Hide-UrlCredential takes it.
    .PARAMETER Text
        The text to show.
    .OUTPUTS
        The text, with each credential replaced by ***.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text
    )

    begin {
        $token = '(?<![A-Za-z0-9_])(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})'
    }

    process {
        $hidden = Hide-UrlCredential -Text $Text
        return $hidden -creplace $token, '***'
    }
}
