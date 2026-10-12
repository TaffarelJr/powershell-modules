function Remove-GitHubGist {
    <#
    .SYNOPSIS
        Deletes a gist.
    .PARAMETER Id
        The gist to delete, by its id or URL.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id
    )

    process {
        $arguments = @('gist', 'delete', $Id, '--yes')
        Invoke-GitHubCommand -Activity "Deleting gist $Id" -Arguments $arguments | Out-Null
    }
}
