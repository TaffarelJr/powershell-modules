function Write-GitHubActionsDebug {
    <#
    .SYNOPSIS
        Writes a debug message, visible only when step debug logging is
        enabled for the run.
    .PARAMETER Message
        The text to log.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Message
    )

    process {
        Write-GitHubActionsCommand -Command 'debug' -Data $Message
    }
}
