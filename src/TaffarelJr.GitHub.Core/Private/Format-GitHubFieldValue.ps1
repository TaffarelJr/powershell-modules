function Format-GitHubFieldValue {
    <#
    .SYNOPSIS
        Returns the text gh api is given for one field value.
    .DESCRIPTION
        Not exported. $null is null, a bool or a switch is true or false in
        lower case, a date is ISO 8601, and a string, number, or URI is its
        invariant text. Anything else throws rather than being sent as its
        type name.
    .PARAMETER Name
        The field's name, for the message.
    .PARAMETER Value
        The value.
    .OUTPUTS
        The text.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name,

        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return 'null'
    }

    if ($Value -is [System.Management.Automation.SwitchParameter]) {
        $Value = $Value.IsPresent
    }

    if ($Value -is [bool]) {
        return $Value.ToString().ToLowerInvariant()
    }

    if ($Value -is [DateTime] -or $Value -is [DateTimeOffset]) {
        return $Value.ToString('o')
    }

    if ($Value -is [string] -or $Value -is [ValueType] -or $Value -is [uri]) {
        return [string]$Value
    }

    $shown = Hide-UrlCredential -Text $Name
    throw "Field '$shown' holds a $($Value.GetType().Name), which gh's fields cannot express - send it with -Body."
}
