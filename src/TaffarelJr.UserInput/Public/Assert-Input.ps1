using namespace System.Collections.Generic
using namespace System.Management.Automation

function Assert-Input {
    <#
    .SYNOPSIS
        Throws when a value breaks its rules; otherwise returns it.
    .DESCRIPTION
        Checked in order: -Require (only an empty value can fail this),
        -Choice, -Pattern, then -Validate - each only reached
        if the value is non-empty and every earlier check passed.
        A value that matches -Choice is re-cased right away
        to match the casing -Choice declares, so -Pattern, -Validate,
        and a later comparison all see that casing.

        Throwing rather than returning a reason
        is what makes this composable:
        pipe Read-Input straight into it for a one-shot check,
        or wrap both in Invoke-InputRetry to re-ask on failure.

        A value that breaks its rules is a terminating error for the call,
        and in a pipeline it stops the pipeline. So is a mistake in how this
        is called, such as -Requirement without -Pattern.
    .PARAMETER Value
        The value to check.
    .PARAMETER Label
        Names the value in the thrown message ("Repo name is required").
        Omit it for a bare message when the context is already obvious.
    .PARAMETER Choice
        Accept only these values, case-insensitively. A list that holds one
        option twice, ignoring case, is refused as a mistake in the call,
        since a value could not be matched to one of them.
    .PARAMETER Pattern
        A regex the value must match when it is not empty. Case-sensitive, so
        '^[a-z]+$' rejects 'ABC' - start it with (?i) to ignore case - and
        not anchored, so use ^ and $ to require the whole value to match.
    .PARAMETER Requirement
        Plain-English version of -Pattern,
        used in the thrown message instead of the regex itself.
        Has no effect without -Pattern.
    .PARAMETER Validate
        A rule too specific for a regex. Gets the value both as its first
        argument and as $_, and returns why the value is unacceptable, or
        nothing. Not a predicate: a boolean it returns is refused as a
        mistake in the call, and so is a number, an object, or anything else
        that is not a string; an empty string or $null counts as nothing.
        Checked last, and only when the value is not empty.
    .PARAMETER Require
        Reject an empty value. Without it, empty passes through untouched,
        skipping every other check.
    .INPUTS
        System.String. The value to check.
    .OUTPUTS
        System.String. The value, re-cased to match -Choice when it is one of
        them.
    .EXAMPLE
        Assert-Input -Value 'Public' -Choice 'Public', 'Private'

        Returns 'Public'; a value that is neither throws.
    .EXAMPLE
        Read-Input -Prompt 'Visibility' -Choice 'Public', 'Private' |
            Assert-Input -Choice 'Public', 'Private' -Label 'Visibility'

        Asks once, and throws unless the answer is one of the two.
    .EXAMPLE
        Read-Input -Prompt 'Folder' |
            Assert-Input -Validate {
                if (-not (Test-Path -LiteralPath $_)) { 'does not exist' }
            }

        Asks once, and throws unless the folder exists.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.UserInput/README.md
    .LINK
        Read-Input
    .LINK
        Invoke-InputRetry
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Value,

        [string]$Label = '',

        [string[]]$Choice,

        [string]$Pattern,

        [string]$Requirement,

        [scriptblock]$Validate,

        [switch]$Require
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            if ($Requirement -and -not $Pattern) {
                $record = New-CallMistakeError `
                    -Message '-Requirement has no effect without -Pattern' `
                    -ErrorId 'RequirementWithoutPattern' `
                    -TargetObject $Requirement
                $PSCmdlet.ThrowTerminatingError($record)
            }

            $seen = [HashSet[string]]::new([StringComparer]::InvariantCultureIgnoreCase)
            foreach ($item in $Choice) {
                if (-not $seen.Add($item)) {
                    $record = New-CallMistakeError `
                        -Message ("-Choice lists '$item' more than once, ignoring case, " +
                            'so a value could not be matched to one') `
                        -ErrorId 'ChoiceDuplicated' `
                        -TargetObject $item
                    $PSCmdlet.ThrowTerminatingError($record)
                }
            }

            if ($Pattern) {
                try {
                    $null = [regex]::new($Pattern)
                }
                catch {
                    $reason = $_.Exception.GetBaseException().Message
                    $record = New-CallMistakeError `
                        -Message "-Pattern is not a valid regular expression: $reason" `
                        -ErrorId 'InvalidPattern' `
                        -TargetObject $Pattern
                    $PSCmdlet.ThrowTerminatingError($record)
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }

    process {
        try {
            $prefix = if ($Label) { "$Label " } else { '' }

            if ([string]::IsNullOrEmpty($Value)) {
                if ($Require) {
                    throw "${prefix}is required"
                }

                return $Value
            }

            if ($Choice) {
                $match = @($Choice -eq $Value)
                if (-not $match) {
                    throw "${prefix}must be one of: $($Choice -join ', ')"
                }

                $Value = $match[0]
            }

            if ($Pattern -and $Value -cnotmatch $Pattern) {
                if ($Requirement) {
                    throw "$prefix$Requirement"
                }

                throw "${prefix}must match $Pattern"
            }

            if ($Validate) {
                $context = [List[psvariable]]::new()
                $context.Add([psvariable]::new('_', $Value))
                try {
                    $reason = @($Validate.InvokeWithContext($null, $context, $Value))
                }
                catch [MethodInvocationException] {
                    throw $_.Exception.InnerException
                }

                $booleans = @($reason | Where-Object { $_ -is [bool] })
                if ($booleans.Count -gt 0) {
                    $record = New-CallMistakeError `
                        -Message '-Validate must return a reason string or nothing, not a boolean' `
                        -ErrorId 'ValidateReturnedBoolean' `
                        -TargetObject $Validate
                    $PSCmdlet.ThrowTerminatingError($record)
                }

                $notText = @($reason | Where-Object { $null -ne $_ -and $_ -isnot [string] })
                if ($notText.Count -gt 0) {
                    $record = New-CallMistakeError `
                        -Message ('-Validate must return a reason string or nothing, ' +
                            "not a [$($notText[0].GetType().Name)]") `
                        -ErrorId 'ValidateReturnedNonString' `
                        -TargetObject $Validate
                    $PSCmdlet.ThrowTerminatingError($record)
                }

                if ($reason) {
                    throw "$prefix$reason"
                }
            }

            return $Value
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
