function Get-GitHubDeployKey {
    <#
    .SYNOPSIS
        Returns a repository's deploy keys.
    .DESCRIPTION
        Each key carries a Repository note property - the repository as
        it was named here, or $null for the current directory's - which
        Remove-GitHubDeployKey reads from the pipeline, so a piped key is
        deleted from the repository it was listed from. A repository named
        by a URL that carries a credential is kept with the credential
        hidden, since the object is printed.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form or as a URL, or a
        repository object such as one a listing returned. Omit it to use
        the current directory's repository.
        A -Repository given as $null throws.
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object per key - Id, Title, Key, ReadOnly, CreatedAt, and
        Repository.
    .EXAMPLE
        Get-GitHubDeployKey -Repository 'OWNER/REPO'

        Lists the deploy keys of OWNER/REPO.
    .EXAMPLE
        Get-GitHubDeployKey -Repository 'OWNER/REPO' |
            Where-Object ReadOnly -EQ $false |
            Remove-GitHubDeployKey

        Deletes every deploy key of OWNER/REPO that can push; each piped
        key is deleted from the repository it was listed from.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Add-GitHubDeployKey
    .LINK
        Remove-GitHubDeployKey
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Position = 0)]
        [object]$Repository
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $given = $PSBoundParameters.ContainsKey('Repository')
        $reference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
        $arguments = @('repo', 'deploy-key', 'list', '--json', 'createdAt,id,key,readOnly,title')
        $out = Invoke-GitHubCommand -Activity 'Listing deploy keys' -Arguments $arguments -Repository $reference
        $keys = @(ConvertFrom-GitHubJson -Lines $out)
        return Add-GitHubScopeProperty -InputObject $keys -Scope ([ordered]@{ Repository = $reference })
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
        )
    }
}
