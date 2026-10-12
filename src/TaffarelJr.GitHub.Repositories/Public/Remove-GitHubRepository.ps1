function Remove-GitHubRepository {
    <#
    .SYNOPSIS
        Deletes a repository from GitHub.
    .DESCRIPTION
        The repository must be named: gh refuses to delete the current
        directory's repository without a confirmation prompt, and nothing
        here can answer one. Deleting needs the delete_repo scope on the
        token.
    .PARAMETER Repository
        The repository to delete, in [HOST/]OWNER/REPO form.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$Repository
    )

    process {
        $arguments = @('repo', 'delete', $Repository, '--yes')
        Invoke-GitHubCommand -Activity "Deleting repository $Repository" -Arguments $arguments | Out-Null
    }
}
