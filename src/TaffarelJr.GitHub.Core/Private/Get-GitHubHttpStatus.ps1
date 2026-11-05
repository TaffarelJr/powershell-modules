function Get-GitHubHttpStatus {
    <#
    .SYNOPSIS
        Returns the HTTP status a failed gh call reports in its message, or
        nothing when it reports none.
    .DESCRIPTION
        Not exported. gh api ends its error with "(HTTP 404)", or says only
        "gh: HTTP 404"; gh's other commands start a line with "HTTP 404:",
        or with their own words first, as in "failed to get run: HTTP 404:".
        A GraphQL error, a network failure, or a missing login carries no
        status.
    .PARAMETER Message
        gh's output, as Invoke-GitHubCommand -Tolerant gives it in Message.
    .OUTPUTS
        The status, as an [int]; nothing when the message names none.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Message
    )

    if ($Message -match '\(HTTP (?<status>[1-5][0-9]{2})\)' -or
        $Message -match '(?m)^(?:gh: )?HTTP (?<status>[1-5][0-9]{2})\b' -or
        $Message -match '(?m)^(?:[^\r\n:]+: )+HTTP (?<status>[1-5][0-9]{2}):') {
        return [int]$Matches['status']
    }
}
