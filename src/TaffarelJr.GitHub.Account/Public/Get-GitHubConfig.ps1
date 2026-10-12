function Get-GitHubConfig {
    <#
    .SYNOPSIS
        Returns one of gh's own configuration values, or lists them all.
    .DESCRIPTION
        This is gh's own local CLI configuration - the editor, git
        protocol, pager, and the like, stored in gh's own config file -
        not a GitHub resource, so there is no API to fall back to. gh
        prints a plain key=value line per setting, which this parses
        itself.
    .PARAMETER Name
        The setting to return, such as 'git_protocol'. Omit it to list
        every setting.
    .PARAMETER Hostname
        Reads the per-host override for this host instead of the global
        setting.
    .OUTPUTS
        With -Name, the setting's value as a string. Without it, one
        object per setting - Name, Value - always an array.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [string]$Hostname
    )

    if ($Name) {
        $arguments = @('config', 'get', $Name)
        if ($Hostname) {
            $arguments += @('--host', $Hostname)
        }

        $out = Invoke-GitHubCommand -Activity "Reading config $Name" -Arguments $arguments
        return $out[0]
    }

    $arguments = @('config', 'list')
    if ($Hostname) {
        $arguments += @('--host', $Hostname)
    }

    $out = Invoke-GitHubCommand -Activity 'Listing config' -Arguments $arguments
    $settings = foreach ($line in $out) {
        $parts = $line.Split('=', 2)
        if ($parts.Count -eq 2) {
            [PSCustomObject]@{
                Name  = $parts[0]
                Value = $parts[1]
            }
        }
    }

    return , @($settings)
}
