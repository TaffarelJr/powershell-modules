using namespace System.Text

function Invoke-NativeCapture {
    <#
    .SYNOPSIS
        Runs an external command and returns its exit code and merged output.
    .DESCRIPTION
        Not exported - the one place output is captured and decoded,
        so Invoke-NativeCommand and Invoke-NativeRead
        cannot disagree about either.

        stderr is merged into the captured output on purpose,
        not by accident: many command-line tools
        write ordinary progress or status there even on success,
        and some write their error bodies to stdout instead -
        a caller inspecting the result needs both streams
        regardless of which one a particular tool favors.
        It also keeps a chatty-but-successful command from surfacing
        as a NativeCommandError.

        The console's output encoding is pinned to UTF-8
        for the call and restored after:
        many native tools emit UTF-8 regardless of the console's own code page,
        so decoding with anything else corrupts every non-ASCII byte.
    .PARAMETER Command
        The executable to run.
    .PARAMETER Arguments
        Passed as an explicit array -
        a loose token like '-C' would otherwise bind as a PowerShell parameter
        instead of an argument to the command, without any error.
    .PARAMETER StdIn
        Piped to the command instead of appearing in its arguments.
    .OUTPUTS
        A hashtable: ExitCode (int) and Output
        (string[], always an array, possibly empty).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [string]$StdIn
    )

    $consoleEncoding = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [UTF8Encoding]::new($false)
        $out = if ($PSBoundParameters.ContainsKey('StdIn')) {
            $StdIn | & $Command @Arguments 2>&1
        }
        else {
            & $Command @Arguments 2>&1
        }

        $exitCode = $LASTEXITCODE
    }
    finally {
        [Console]::OutputEncoding = $consoleEncoding
    }

    # Typed, so one line stays an array rather than becoming a string,
    # and a command that printed nothing still ends up as an empty array
    # instead of $null.
    [string[]]$lines = @()
    if ($null -ne $out) {
        $lines = $out
    }

    return @{
        ExitCode = $exitCode
        Output   = $lines
    }
}
