function Assert-Equal {
    <#
    .SYNOPSIS
        Asserts two values are equal, printing both on failure.
    .DESCRIPTION
        Strictly: strings compare code point by code point, so case counts
        and so does an invisible character such as a byte order mark, and
        never equal a number or a boolean; $null equals only $null, and an
        array equals only an array with equal elements in the same order.
        Dictionaries are compared by their keys, exactly ('a' is not 'A'),
        and their values. PSCustomObjects are compared by their property
        names, case-sensitively, and their values. Nested values are compared the
        same way. Numbers of different types compare by value, exactly, and
        NaN equals NaN; the numbers are the primitive integer and
        floating-point types and decimal, so a BigInteger, Int128, UInt128
        or Half compares by type and Equals. A decimal matches a
        floating-point number only when it is the nearest one to it, so
        [decimal]0.3 equals 0.3 but not 0.1 + 0.2. An XML node is compared
        by its markup. Any other object must be the same type and Equals.

        A failure prints both values. When they print alike although they
        differ - a float and a double inside a list, say - the line says so.

        Both values are required, even when one is $null, so a forgotten
        -Actual cannot pass by accident.

        A case that fails is counted and printed, not thrown: the file's
        exit code, from Complete-TestRun, is how it reaches the run.
    .PARAMETER Expected
        The value the case requires.
    .PARAMETER Actual
        The value produced by the code under test.
    .PARAMETER Message
        Names the case: what was checked, under what condition.
    .INPUTS
        None.
    .OUTPUTS
        None. The case is counted and printed.
    .EXAMPLE
        Assert-Equal -Expected 4 -Actual (2 + 2) -Message '2 and 2 make 4'

        Passes, since both values are the number 4.
    .EXAMPLE
        $names = Get-ChildItem -LiteralPath $folder -Name
        Assert-Equal -Expected @('a.txt', 'b.txt') -Actual $names `
            -Message 'The folder holds both files'

        Compares two arrays element by element, in order; a difference in any
        element, or in the type of one, fails and prints both values.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.TestKit/README.md
    .LINK
        Assert-That
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        $Expected,

        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        $Actual,

        [Parameter(Mandatory)]
        [string]$Message
    )

    try {
        $ErrorActionPreference = 'Stop'

        $equal = Test-ValueEqual -Expected $Expected -Actual $Actual
        $text = $Message
        if (-not $equal) {
            $expectedText = Format-TestValue -Value $Expected -Other $Actual
            $actualText = Format-TestValue -Value $Actual -Other $Expected
            $hint = ''
            if ($expectedText -ceq $actualText) {
                $hint = ' - the values print alike but differ'
            }

            $text = "$Message (expected $expectedText, got $actualText$hint)"
        }

        Assert-That -Condition $equal -Message $text
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
