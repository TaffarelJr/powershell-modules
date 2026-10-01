function Get-EnvironmentValue {
    <#
    .SYNOPSIS
        Reads one environment variable from one place: this process, or the
        User or Machine settings.
    .DESCRIPTION
        Not exported. A function of its own so a test can stand in for the
        User and Machine settings instead of reading the real ones.
    .PARAMETER Name
        The variable to read.
    .PARAMETER Target
        Where to read it from.
    .OUTPUTS
        The value, or $null when it is not set there.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [EnvironmentVariableTarget]$Target
    )

    return [Environment]::GetEnvironmentVariable($Name, $Target)
}
