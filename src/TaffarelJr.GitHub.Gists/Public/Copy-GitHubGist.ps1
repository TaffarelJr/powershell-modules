function Copy-GitHubGist {
    <#
    .SYNOPSIS
        Clones a gist locally.
    .PARAMETER Id
        The gist to clone, by its id or URL.
    .PARAMETER Destination
        The folder to clone into. gh's default is the gist's id.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,

        [Parameter(Position = 1)]
        [string]$Destination
    )

    process {
        $arguments = @('gist', 'clone', $Id)
        if ($Destination) {
            $arguments += $Destination
        }

        Invoke-GitHubCommand -Activity "Cloning gist $Id" -Arguments $arguments | Out-Null
    }
}
