function Get-EnvironmentVariable {
    <#
    .SYNOPSIS
        Returns an environment variable's value, or $null if it is unset.
    .DESCRIPTION
        Looks in this process first, then - on Windows - in the User and
        Machine settings. A value that Set-EnvironmentVariable saved reaches
        a terminal that was already open only through those settings, so
        without the second look the next run, from that same terminal, would
        ask for it again.

        Returned exactly as stored, so a secret saved with Read-Secret and
        Set-EnvironmentVariable comes back unchanged. A whitespace-only value
        is treated the same as unset - a variable holding only spaces is not
        meaningfully "set" to a caller deciding whether to prompt instead.
    .PARAMETER Name
        The environment variable to read. A blank name, one that starts with
        a space, or one that contains '=' is refused.
    .INPUTS
        None. The name is given with -Name.
    .OUTPUTS
        System.String. The value, or nothing when the variable is unset.
    .EXAMPLE
        $name = Get-EnvironmentVariable -Name 'REPO_NAME'
        if (-not $name) { $name = Read-Input -Prompt 'Repo name' }

        Asks only when the variable is not already set.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.UserInput/README.md
    .LINK
        Set-EnvironmentVariable
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern(
            '^[^=\s][^=]*\z',
            ErrorMessage = "Environment variable name '{0}' must not be blank, start with a space, or contain '='")]
        [string]$Name
    )

    try {
        $ErrorActionPreference = 'Stop'

        $value = Get-EnvironmentValue -Name $Name -Target Process
        if ([string]::IsNullOrWhiteSpace($value) -and $IsWindows) {
            foreach ($target in 'User', 'Machine') {
                $value = Get-EnvironmentValue -Name $Name -Target $target
                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    break
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($value)) {
            return
        }

        return $value
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
