function Hide-GitHubActionsValue {
    <#
    .SYNOPSIS
        Masks a value out of the run's log, replacing it with '***'
        everywhere it appears from this point on.
    .DESCRIPTION
        Masking applies to this job's log only, and only to output
        written after this call - earlier lines, and any other job, are
        unaffected.

        The value is sent whole. The runner masks it whole, and also each
        of its lines on its own, since the log is masked a line at a time.

        Any non-blank value is masked, however short: masking a short or
        common string, such as '1', blots it out everywhere in the log.
        A blank value, or none at all, is ignored, so an optional secret
        can be passed whether it is set or not.
    .PARAMETER Value
        The secret, as text or as a SecureString. Anything else throws,
        since its text would not be the secret.
    .INPUTS
        System.String or System.Security.SecureString. The value to mask.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Hide-GitHubActionsValue $env:OPTIONAL_TOKEN

        Masks the token if it is set, and does nothing if it is not.
    .EXAMPLE
        $secret | Hide-GitHubActionsValue

        Masks each value taken from the pipeline, a string or a SecureString.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.WorkflowCommands/README.md
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyString()]
        [object]$Value
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            if ($Value -is [securestring]) {
                $text = [System.Net.NetworkCredential]::new('', $Value).Password
            }
            elseif ($null -eq $Value -or $Value -is [string]) {
                $text = [string]$Value
            }
            else {
                throw ("A value of type $($Value.GetType().Name) cannot be masked; " +
                    "give the secret's text, as a string or a SecureString.")
            }

            if ([string]::IsNullOrWhiteSpace($text)) {
                return
            }

            Write-GitHubActionsCommand -Command 'add-mask' -Data $text
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
