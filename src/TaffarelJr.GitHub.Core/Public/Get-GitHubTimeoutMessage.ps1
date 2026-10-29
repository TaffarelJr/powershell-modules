function Get-GitHubTimeoutMessage {
    <#
    .SYNOPSIS
        Returns the message a waiter's TimeoutException carries.
    .DESCRIPTION
        The shape every TaffarelJr.GitHub.* waiter shares, for the deadline
        Test-GitHubPollExpired reports: what was still pending, then what to
        do. Every read before the deadline worked - a failed one ends the
        wait through Assert-GitHubPollRead - so the subject says it all.
        Any credential in the subject is hidden by Hide-UrlCredential.

        Names that were still pending go in -Detail, not in the subject:
        each is hidden on its own, so an @ in one name cannot hide the words
        of the sentence before it.
    .PARAMETER Subject
        What was still pending, as a sentence - such as 'Workflow run 7
        was still in_progress after 30 s.' With -Detail, the sentence stops
        where the names begin, as in 'Checks were still pending:'.
    .PARAMETER Detail
        The names to follow the subject, joined with commas and ended with a
        full stop.
    .INPUTS
        None
    .OUTPUTS
        System.String
        The message.
    .EXAMPLE
        $subject = 'Workflow run 7 was still queued after 30 s.'
        Get-GitHubTimeoutMessage -Subject $subject

        Gives 'Workflow run 7 was still queued after 30 s. Give a longer
        -TimeoutSeconds to wait more.'
    .EXAMPLE
        Get-GitHubTimeoutMessage -Subject 'Checks were still pending:' `
            -Detail 'build', 'lint'

        Gives 'Checks were still pending: build, lint. Give a longer
        -TimeoutSeconds to wait more.'
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Subject,

        [string[]]$Detail
    )

    try {
        $ErrorActionPreference = 'Stop'

        $message = Hide-UrlCredential -Text $Subject
        if ($Detail) {
            $names = @($Detail | Hide-UrlCredential)
            $message = "$message $($names -join ', ')."
        }

        return "$message Give a longer -TimeoutSeconds to wait more."
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
