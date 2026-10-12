using namespace System.Text.Json

function ConvertFrom-GitHubJsonScalar {
    <#
    .SYNOPSIS
        Converts a JSON string, number, true, false, or null element into
        its PowerShell value.
    .DESCRIPTION
        Not exported. A string stays a string. A number is an [long] when
        it is a whole number that fits one, a [decimal] when it fits that,
        and a [double] otherwise; one too large even for a double stays the
        text the JSON had, rather than becoming infinity.
    .PARAMETER Element
        The JSON value.
    .OUTPUTS
        A string, long, decimal, double, or bool; nothing for null.
    #>
    param(
        [Parameter(Mandatory)]
        [JsonElement]$Element
    )

    switch ($Element.ValueKind) {
        'String' {
            return $Element.GetString()
        }
        'Number' {
            $long = 0L
            if ($Element.TryGetInt64([ref]$long)) {
                return $long
            }

            $decimal = 0D
            if ($Element.TryGetDecimal([ref]$decimal)) {
                return $decimal
            }

            $double = 0.0
            if ($Element.TryGetDouble([ref]$double) -and [double]::IsFinite($double)) {
                return $double
            }

            return $Element.GetRawText()
        }
        'True' {
            return $true
        }
        'False' {
            return $false
        }
    }
}
