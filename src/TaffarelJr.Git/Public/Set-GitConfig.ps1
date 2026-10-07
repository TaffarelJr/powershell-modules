function Set-GitConfig {
    <#
    .SYNOPSIS
        Writes a config value.
    .PARAMETER Name
        The config key, such as 'user.name'.
    .PARAMETER Value
        The value to set it to.
    .PARAMETER Global
        Writes to the global config instead of the repo's own.
    .PARAMETER RepoPath
        The repo to write to. Omit it to use the current working
        directory. Ignored with -Global.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [string]$Value,

        [switch]$Global,

        [string]$RepoPath
    )

    $arguments = @('config')
    if ($Global) {
        $arguments += '--global'
    }

    $arguments += @($Name, $Value)
    Invoke-GitCommand -Activity "Setting $Name" -Arguments $arguments -RepoPath $RepoPath | Out-Null
}
