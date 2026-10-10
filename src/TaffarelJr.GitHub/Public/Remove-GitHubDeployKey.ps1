function Remove-GitHubDeployKey {
    <#
    .SYNOPSIS
        Deletes a deploy key from a repository.
    .PARAMETER Id
        The key's id, as Get-GitHubDeployKey reports it.
    .PARAMETER Repository
        The repository to delete it from, in [HOST/]OWNER/REPO form. Omit
        it to use the current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [long]$Id,

        [string]$Repository
    )

    process {
        $arguments = @('repo', 'deploy-key', 'delete', $Id)
        Invoke-GitHubCommand -Activity "Deleting deploy key $Id" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
