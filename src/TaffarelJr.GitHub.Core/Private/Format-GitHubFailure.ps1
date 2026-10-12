using namespace System.Collections

function Format-GitHubFailure {
    <#
    .SYNOPSIS
        Returns the message for a failed gh call: what failed, the HTTP
        status or exit code, and what gh printed, with every credential
        hidden.
    .DESCRIPTION
        Not exported. The shape Test-GitHubApi and Assert-GitHubPollRead
        share: "<Subject> (HTTP 403):" or "<Subject> (exit 1):", then gh's
        output on the lines below, each line through
        Hide-GitHubCredential on its own. A call that printed nothing
        says so.
    .PARAMETER Subject
        What failed, such as "Could not read workflow run 9".
    .PARAMETER Result
        What Invoke-GitHubCommand -Tolerant returned for the failed call.
    .OUTPUTS
        The message.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Subject,

        [Parameter(Mandatory)]
        [IDictionary]$Result
    )

    $printed = "$($Result['Message'])".Trim()
    $status = Get-GitHubHttpStatus -Message $printed
    $code = if ($null -ne $status) { "HTTP $status" } else { "exit $($Result['ExitCode'])" }
    $lead = "$(Hide-GitHubCredential -Text $Subject) ($code):"
    if (-not $printed) {
        return "$lead gh printed nothing."
    }

    $lines = @($printed -split '\r?\n' | Hide-GitHubCredential)
    return "$lead`n$($lines -join "`n")"
}
