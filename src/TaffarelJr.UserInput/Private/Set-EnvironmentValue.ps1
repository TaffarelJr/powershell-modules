function Set-EnvironmentValue {
    <#
    .SYNOPSIS
        Writes one environment variable to one place: this process, or the
        User or Machine settings.
    .DESCRIPTION
        Not exported. A function of its own so a test can stand in for the
        User settings, which a test must never change.
    .PARAMETER Name
        The variable to write.
    .PARAMETER Value
        The value. Empty removes the variable there.
    .PARAMETER Target
        Where to write it.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Set-EnvironmentVariable, its public caller, asks ShouldProcess for each scope first.')]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory)]
        [EnvironmentVariableTarget]$Target
    )

    # .NET 9 and later set an empty value for '' and delete only for null.
    if ($Value -ceq '') {
        [Environment]::SetEnvironmentVariable($Name, [NullString]::Value, $Target)
    }
    else {
        [Environment]::SetEnvironmentVariable($Name, $Value, $Target)
    }
}
