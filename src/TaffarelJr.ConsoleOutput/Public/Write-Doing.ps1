function Write-Doing {
    <#
    .SYNOPSIS
        Announces what a step is about to attempt, on a line left open.
    .DESCRIPTION
        Pair it with Write-Done.
        Anything this module prints in between closes this line first
        instead of running on to the end of it.
        Other output - Write-Warning, a native command,
        pipeline output reaching the host - does not,
        so close the line with Write-Done before any of that.
    .PARAMETER Text
        What the step is attempting. A later line of a multi-line text
        is indented under the first line's text.
    .INPUTS
        System.String. What the step is attempting;
        each one is printed in turn.
    .OUTPUTS
        None. The line is written to the host, left open.
    .EXAMPLE
        Write-Doing 'Compiling'
        Write-Done

        Announces the step, then ends its line with "done" once the work
        is over.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Write-Done
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            $null = Open-DoingLine -Text $Text
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
