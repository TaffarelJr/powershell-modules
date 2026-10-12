function Get-GitHubDefaultRepository {
    <#
    .SYNOPSIS
        Returns the repository gh treats as the default for the current
        directory's clone, or nothing when none is set.
    .DESCRIPTION
        Outside a git repository there is no clone to have a default, and
        that throws, with gh's message, rather than reading as "none set".
    .INPUTS
        None.
    .OUTPUTS
        System.String
        The default repository as OWNER/REPO, or nothing.
    .EXAMPLE
        Get-GitHubDefaultRepository

        Returns OWNER/REPO when gh has a default repository set for this
        clone, and nothing when it has none.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Set-GitHubDefaultRepository
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $arguments = @('repo', 'set-default', '--view')
        $out = @(Invoke-GitHubCommand -Activity 'Reading the default repository' -Arguments $arguments)
        if ($out.Count -eq 0) {
            return
        }

        return $out[0]
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
        )
    }
}
