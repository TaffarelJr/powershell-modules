function Set-GitHubDefaultRepository {
    <#
    .SYNOPSIS
        Sets, or unsets, the repository gh treats as the default for the
        current directory's clone.
    .DESCRIPTION
        A clone with several GitHub remotes - a fork and its upstream -
        leaves gh unsure which one a pull request or run command means;
        the default settles that. gh does not consult it for secrets.
    .PARAMETER Repository
        The repository to make the default, in [HOST/]OWNER/REPO form, or
        the name of a git remote that points at it.
    .PARAMETER Unset
        Clears the default instead.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Set')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Set')]
        [string]$Repository,

        [Parameter(Mandatory, ParameterSetName = 'Unset')]
        [switch]$Unset
    )

    $arguments = if ($Unset) {
        @('repo', 'set-default', '--unset')
    }
    else {
        @('repo', 'set-default', $Repository)
    }

    Invoke-GitHubCommand -Activity 'Setting the default repository' -Arguments $arguments | Out-Null
}
