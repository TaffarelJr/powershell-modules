function Set-GitHubGist {
    <#
    .SYNOPSIS
        Changes a gist's description, adds or removes a file, or
        replaces a file's content from a local file.
    .PARAMETER Id
        The gist to change, by its id or URL.
    .PARAMETER Description
        The new description.
    .PARAMETER AddFile
        A local file to add to the gist.
    .PARAMETER RemoveFile
        The name of a file to remove from the gist.
    .PARAMETER FileName
        The gist file to replace, together with -ReplaceWith.
    .PARAMETER ReplaceWith
        A local file whose content replaces -FileName's.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Id,

        [string]$Description,

        [string]$AddFile,

        [string]$RemoveFile,

        [string]$FileName,

        [string]$ReplaceWith
    )

    process {
        $arguments = @('gist', 'edit', $Id)
        if ($Description) {
            $arguments += @('--desc', $Description)
        }

        if ($AddFile) {
            $arguments += @('--add', $AddFile)
        }

        if ($RemoveFile) {
            $arguments += @('--remove', $RemoveFile)
        }

        if ($FileName) {
            $arguments += @('--filename', $FileName)
        }

        if ($ReplaceWith) {
            $arguments += $ReplaceWith
        }

        Invoke-GitHubCommand -Activity "Editing gist $Id" -Arguments $arguments | Out-Null
    }
}
