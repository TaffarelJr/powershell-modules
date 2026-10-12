function Set-GitHubConfig {
    <#
    .SYNOPSIS
        Updates one of gh's own configuration values.
    .DESCRIPTION
        This is gh's own local CLI configuration, not a GitHub resource -
        see Get-GitHubConfig for why.
    .PARAMETER Name
        The setting to change, such as 'editor'.
    .PARAMETER Value
        The new value.
    .PARAMETER Hostname
        Sets the per-host override for this host instead of the global
        setting.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [AllowEmptyString()]
        [string]$Value,

        [string]$Hostname
    )

    $arguments = @('config', 'set', $Name, $Value)
    if ($Hostname) {
        $arguments += @('--host', $Hostname)
    }

    Invoke-GitHubCommand -Activity "Setting config $Name" -Arguments $arguments | Out-Null
}
