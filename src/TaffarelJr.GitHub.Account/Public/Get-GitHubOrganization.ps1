function Get-GitHubOrganization {
    <#
    .SYNOPSIS
        Returns the organizations the authenticated user belongs to.
    .DESCRIPTION
        gh's own org list has no --json support, so this calls GitHub's
        REST API directly (user/orgs). Every page is read, so the list is
        never cut short.
    .PARAMETER Hostname
        Asks this host's API (gh's --hostname), for the account gh is
        logged in to there. Omit it for gh's default host. An empty value
        is refused; leave it out for the default.
    .INPUTS
        None
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object per organization, with the fields GitHub returns - Login,
        Id, Description, Url, and the rest - in PascalCase.
    .EXAMPLE
        Get-GitHubOrganization | Select-Object Login, Description

        Lists the organizations the signed-in user belongs to.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Account/README.md
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSCustomObject])]
    param(
        [ValidateScript({ Assert-GitHubHostname -Hostname $_ })]
        [string]$Hostname
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $api = @{
            Endpoint = 'user/orgs?per_page=100'
            Paginate = $true
        }
        if ($PSBoundParameters.ContainsKey('Hostname')) {
            $api.Hostname = $Hostname
        }

        $organizations = @(Invoke-GitHubApi @api)
        return ConvertTo-PascalCaseObject -InputObject $organizations
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
