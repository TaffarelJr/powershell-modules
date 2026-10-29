function Write-GitHubActionsDebug {
    <#
    .SYNOPSIS
        Writes a debug message, visible only when step debug logging is
        enabled for the run.
    .DESCRIPTION
        Writes the message as a debug workflow command, which the runner
        shows in the step's log only when step debug logging is on for the
        run, and leaves out otherwise.

        A piped object gives its Message property as text, so a number is
        its digits; an object without a Message property throws rather than
        being written as its own text.
    .PARAMETER Message
        The text to log. Also taken from a piped string, a piped
        Select-String match's line, a piped error record's message, or a
        piped object's Message property.
    .INPUTS
        System.Object. A string, a Select-String match, an error record, or
        an object with a Message property.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Write-GitHubActionsDebug -Message 'Cache key is v1-abc123'

        Writes a message the log shows only when step debug logging is on.
    .EXAMPLE
        'restoring', 'building' | Write-GitHubActionsDebug

        Writes one debug message for each piped string.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.WorkflowCommands/README.md
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [object]$Message
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            $messageGiven = $PSBoundParameters.ContainsKey('Message')
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }

    process {
        try {
            $text = if ($messageGiven) {
                [string]$Message
            }
            else {
                ConvertTo-GitHubActionsMessageText -Message $Message
            }

            Write-GitHubActionsCommand -Command 'debug' -Data $text
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
