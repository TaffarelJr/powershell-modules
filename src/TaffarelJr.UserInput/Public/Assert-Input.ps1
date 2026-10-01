function Assert-Input {
    <#
    .SYNOPSIS
        Throws when a value breaks its rules; otherwise returns it.
    .DESCRIPTION
        Checked in order: -Require (only an empty value can fail this),
        -Choice, -Pattern, then -Validate - each only reached
        if the value is non-empty and every earlier check passed.
        A value that matches -Choice comes back re-cased
        to match the casing -Choice declares,
        so a later comparison can be a plain string match.

        Throwing rather than returning a reason
        is what makes this composable:
        pipe Read-Input straight into it for a one-shot check,
        or wrap both in Invoke-InputRetry to re-ask on failure.
    .PARAMETER Value
        The value to check.
    .PARAMETER Label
        Names the value in the thrown message ("Repo name is required").
        Omit it for a bare message when the context is already obvious.
    .PARAMETER Choice
        Accept only these values, case-insensitively.
    .PARAMETER Pattern
        A regex the value must match when it is not empty.
    .PARAMETER Requirement
        Plain-English version of -Pattern,
        used in the thrown message instead of the regex itself.
        Has no effect without -Pattern.
    .PARAMETER Validate
        A rule too specific for a regex.
        Takes the value, returns why it is unacceptable or $null.
        Checked last, and only when the value is not empty.
    .PARAMETER Require
        Reject an empty value. Without it, empty passes through untouched,
        skipping every other check.
    .EXAMPLE
        Read-Input -Prompt 'Visibility' -Choice 'Public', 'Private' |
            Assert-Input -Choice 'Public', 'Private' -Label 'Visibility'
    #>
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
        if ($Requirement -and -not $Pattern) {
            throw '-Requirement has no effect without -Pattern'
        }
    }

    process {
        $prefix = if ($Label) { "$Label " } else { '' }

        if ([string]::IsNullOrEmpty($Value)) {
            if ($Require) { throw "${prefix}is required" }
            return $Value
        }

        if ($Choice -and $Value -notin $Choice) {
            throw "${prefix}must be one of: $($Choice -join ', ')"
        }

        if ($Pattern -and $Value -notmatch $Pattern) {
            if ($Requirement) { throw "$prefix$Requirement" }
            throw "${prefix}must match $Pattern"
        }

        if ($Validate) {
            $reason = & $Validate $Value
            if ($reason) { throw "$prefix$reason" }
        }

        if ($Choice) {
            $match = @($Choice | Where-Object { $_ -eq $Value })
            if ($match) { return $match[0] }
        }

        return $Value
    }
}
