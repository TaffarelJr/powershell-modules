function Invoke-NativeRead {
    <#
    .SYNOPSIS
        Runs an external command whose failure is survivable,
        and returns whether it worked along with what it said.
    .DESCRIPTION
        Never throws. For a read whose failure must not end the run,
        but must not be mistaken for an answer either:
        the exit code is reported rather than discarded,
        and the output is kept whatever it was -
        some tools write their error bodies to stdout,
        and a caller may need to read them.

        Resets $LASTEXITCODE to 0 before returning,
        so a tolerated failure does not leave a phantom behind
        for a later, unrelated check to trip on.
    .PARAMETER Command
        The executable to run.
    .PARAMETER Arguments
        Passed as an explicit array - a loose token like '-C'
        would otherwise bind as a PowerShell parameter
        instead of an argument to the command, without any error.
    .OUTPUTS
        A hashtable: Ok (bool), ExitCode (int), and Output (string[],
        always an array).
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Command,

        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $result = Invoke-NativeCapture -Command $Command -Arguments $Arguments
    $global:LASTEXITCODE = 0

    return @{
        Ok       = ($result.ExitCode -eq 0)
        ExitCode = $result.ExitCode
        Output   = $result.Output
    }
}
