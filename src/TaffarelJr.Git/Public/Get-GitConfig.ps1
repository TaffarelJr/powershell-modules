function Get-GitConfig {
    <#
    .SYNOPSIS
        Returns a config value, or $null when it is not set.
    .PARAMETER Name
        The config key, such as 'user.name'.
    .PARAMETER Global
        Reads the global config instead of the repo's own.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
        Ignored with -Global.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [switch]$Global,

        [string]$RepoPath
    )

    $arguments = @('config')
    if ($Global) {
        $arguments += '--global'
    }

    $arguments += @('--get', $Name)

    $read = Invoke-GitCommand -Activity "Reading $Name" -Arguments $arguments -RepoPath $RepoPath -Tolerant
    if (-not $read.Ok) {
        return $null
    }

    return ($read.Output -join '').Trim()
}
