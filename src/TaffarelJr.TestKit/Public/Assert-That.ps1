function Assert-That {
    <#
    .SYNOPSIS
        Records one pass/fail case against a boolean condition.
    .DESCRIPTION
        A failure also says where in the test file the assertion was made.
        Safe to call from any runspace: all of them share one tally.

        A case that fails is counted and printed, not thrown: the file's
        exit code, from Complete-TestRun, is how it reaches the run.
    .PARAMETER Condition
        The condition being asserted: $true or $false, as a comparison
        gives. Anything else is refused with an error, not counted as a
        case, since a number or a text read as a boolean passes whenever it
        is not zero or empty. Write the comparison out, such as
        $items.Count -gt 0.
        Evaluate it before calling, not inline,
        so the failure message can describe what was checked.
    .PARAMETER Message
        Names the case: what was checked, under what condition.
    .INPUTS
        None.
    .OUTPUTS
        None. The case is counted and printed.
    .EXAMPLE
        $exists = Test-Path -LiteralPath $path
        Assert-That -Condition $exists -Message 'The file was created'

        Records one passed or failed case, and prints it with the message.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.TestKit/README.md
    .LINK
        Assert-Equal
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'Reports a test result to the person at the console; it is not data.')]
    param(
        [Parameter(Mandatory)]
        [object]$Condition,

        [Parameter(Mandatory)]
        [string]$Message
    )

    try {
        $ErrorActionPreference = 'Stop'

        if ($Condition -isnot [bool]) {
            $type = $Condition.GetType().Name
            throw [ArgumentException]::new(
                "-Condition must be `$true or `$false, not $type; write the comparison out, " +
                'such as $items.Count -gt 0.',
                'Condition')
        }

        Add-TestResult -Passed $Condition
        if ($Condition) {
            Write-Host "  ok - $Message" -ForegroundColor Green
        }
        else {
            Write-Host "  FAIL - $Message$(Get-TestCaller)" -ForegroundColor Red
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
