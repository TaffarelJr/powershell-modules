function Invoke-NativeCommand {
    <#
    .SYNOPSIS
        Runs an external command with its output captured,
        and throws if it fails.
    .DESCRIPTION
        Only for calls where a non-zero exit is genuinely an error.
        A call whose failure is itself a meaningful answer
        rather than an error should use Invoke-NativeRead instead.
    .PARAMETER Activity
        What was being attempted, as a phrase that reads before "failed".
    .PARAMETER Command
        The executable to run.
    .PARAMETER Arguments
        Passed as an explicit array - a loose token like '-C'
        would otherwise bind as a PowerShell parameter
        instead of an argument to the command, without any error.
    .PARAMETER StdIn
        Piped to the command instead of appearing in its arguments.
        Use this for a value that must not reach the console:
        the failure message below renders the whole argument vector,
        so a secret passed as an argument would be printed by it.
    .OUTPUTS
        The command's output lines, always as an array -
        the leading comma on the return is what keeps a single line
        from unrolling to a scalar.
        A caller must never wrap a call to this in @(),
        which would nest that array inside another.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Activity,

        [Parameter(Mandatory)]
        [string]$Command,

        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [string]$StdIn
    )

    $extra = @{}
    if ($PSBoundParameters.ContainsKey('StdIn')) {
        $extra['StdIn'] = $StdIn
    }

    $result = Invoke-NativeCapture -Command $Command -Arguments $Arguments @extra
    if ($result.ExitCode -ne 0) {
        $detail = ($result.Output | Out-String).Trim()
        $message = "$Activity failed: $Command $($Arguments -join ' ') (exit $($result.ExitCode))"
        if ($detail) {
            $message += "`n$detail"
        }

        throw $message
    }

    return , $result.Output
}
