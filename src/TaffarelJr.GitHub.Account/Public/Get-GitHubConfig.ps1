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

        A setting gh has a default for (git_protocol, prompt, and others)
        reads as that default even when it was never set. One with no value
        and no default is an empty string. A name gh does not know throws.

        The stored token is refused: gh hands it out as the oauth_token
        setting of a host, but it is a secret. Get-GitHubToken reads it.
    .PARAMETER Name
        The setting to return, such as 'git_protocol'. Omit it to list
        every setting. An empty value is refused; leave it out to list
        every setting.
    .PARAMETER Hostname
        The host whose settings to read (gh's --host). With -Name, reads
        this host's value, which is the global value (or gh's default)
        when the host sets none. Without -Name, lists the settings in
        effect for this host. A list without -Hostname shows the settings
        in effect for gh's default host, its own overrides included - only
        -Name without -Hostname reads the global value alone. An empty
        value is refused; leave it out for the default.
    .INPUTS
        None
    .OUTPUTS
        System.String
        With -Name, the setting's value.
        System.Management.Automation.PSCustomObject
        Without -Name, one object per setting - Name, Value.
    .EXAMPLE
        Get-GitHubConfig -Name 'git_protocol'

        Returns the protocol gh configures git to use, such as https or ssh.
    .EXAMPLE
        Get-GitHubConfig -Hostname 'ghe.example.com' | Where-Object Value

        Lists the settings in effect for ghe.example.com that have a value.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Account/README.md
    .LINK
        Set-GitHubConfig
    #>
    [CmdletBinding()]
    [OutputType([string], [PSCustomObject])]
    param(
        [Parameter(Position = 0)]
        [ValidatePattern(
            '\S',
            ErrorMessage = "'{0}' is not a setting name: give one such as editor, or leave -Name out to list all."
        )]
        [string]$Name,

        [ValidateScript({ Assert-GitHubHostname -Hostname $_ })]
        [string]$Hostname
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        if ($Name) {
            if ($Name -eq 'oauth_token') {
                throw "-Name '$Name' is not read here: '$Name' is the stored token, a secret." +
                ' Use Get-GitHubToken, which returns it as one.'
            }

            $arguments = @('config', 'get')
            if ($Hostname) {
                $arguments += @('--host', $Hostname)
            }

            # After the --, a name that starts with a dash is still a name.
            $arguments += @('--', $Name)
            $out = @(Invoke-GitHubCommand -Activity "Reading config $Name" -Argument $arguments)

            # gh prints nothing at all for a setting with no value.
            if ($out.Count -eq 0) {
                return ''
            }

            return $out[0]
        }

        $arguments = @('config', 'list')
        if ($Hostname) {
            $arguments += @('--host', $Hostname)
        }

        $out = Invoke-GitHubCommand -Activity 'Listing config' -Argument $arguments
        foreach ($line in $out) {
            $parts = $line.Split('=', 2)
            if ($parts.Count -eq 2) {
                [PSCustomObject]@{
                    Name  = $parts[0]
                    Value = $parts[1]
                }
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
