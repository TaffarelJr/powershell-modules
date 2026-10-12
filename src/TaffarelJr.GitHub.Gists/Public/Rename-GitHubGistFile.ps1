function Rename-GitHubGistFile {
    <#
    .SYNOPSIS
        Renames a file within a gist.
    .PARAMETER Id
        The gist, by its id or URL.
    .PARAMETER OldName
        The file's current name.
    .PARAMETER NewName
        The file's new name.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string]$Id,

        [Parameter(Mandatory, Position = 1)]
        [string]$OldName,

        [Parameter(Mandatory, Position = 2)]
        [string]$NewName
    )

    process {
        $arguments = @('gist', 'rename', $Id, $OldName, $NewName)
        Invoke-GitHubCommand -Activity "Renaming $OldName in gist $Id" -Arguments $arguments | Out-Null
    }
}
