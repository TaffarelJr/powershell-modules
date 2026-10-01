function Hide-MaskedValue {
    <#
    .SYNOPSIS
        Returns text with every occurrence of each given value replaced by
        ***.
    .DESCRIPTION
        For text a person reads - a message, a command line, a line a command
        printed - that may hold a secret the caller passed as a value rather
        than inside a URL, such as a password given as an argument. The caller
        names the values; each is hidden wherever it appears, and everything
        else is kept as it is.

        Values are matched exactly: by ordinal comparison, so case counts and
        no culture changes the result. The longest value is matched first, so
        a value that holds another is hidden whole. A value of fewer than
        four characters is ignored: hiding it would garble the text and
        protect nothing real. A $null or empty value is ignored too, and so
        is a $null or empty list.

        This does not hide the credential a URL carries; Hide-UrlCredential
        does, and a message that can hold either goes through both. The text
        is taken as an argument or from the pipeline, one string at a time,
        as Hide-UrlCredential takes it.
    .PARAMETER Text
        The text to hide the values in. $null and empty text give empty
        text.
    .PARAMETER Mask
        The values to hide, as plain text: a SecureString is refused, since
        it would hide only its type name. $null, an empty list, and $null or
        empty entries are allowed and ignored, so a caller passes the list it
        was given whether or not it holds anything. An entry of fewer than
        four characters is ignored.
    .INPUTS
        System.String. The text, one string at a time.
    .OUTPUTS
        System.String. The text, with every occurrence of each value replaced
        by ***.
    .EXAMPLE
        $line = 'git config password hunter2hunter2'
        Hide-MaskedValue -Text $line -Mask 'hunter2hunter2'

        Returns 'git config password ***'.
    .EXAMPLE
        $shown = @($result.Output | Hide-MaskedValue -Mask $secret) -join "`n"

        Hides the value in each line a command printed.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ProcessInvocation/README.md
    .LINK
        Hide-UrlCredential
    .LINK
        Invoke-NativeCommand
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory, Position = 1)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [object[]]$Mask
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            $pattern = $null
            $values = @(ConvertTo-MaskList -Mask $Mask | Where-Object { $_.Length -ge 4 })
            if ($values.Count -gt 0) {
                $longestFirst = @($values | Sort-Object -Property Length -Descending)
                $escaped = @($longestFirst | ForEach-Object { [regex]::Escape($_) })
                $pattern = [regex]::new($escaped -join '|')
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }

    process {
        try {
            $hidden = $Text
            if ($null -ne $pattern) {
                $hidden = $pattern.Replace($Text, '***')
            }

            return $hidden
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
