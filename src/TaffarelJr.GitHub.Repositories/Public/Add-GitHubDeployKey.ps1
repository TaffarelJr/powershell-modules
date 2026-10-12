function Add-GitHubDeployKey {
    <#
    .SYNOPSIS
        Adds a public SSH key to a repository as a deploy key.
    .DESCRIPTION
        GitHub ties a key added this way to the token that added it; if
        that token is later revoked, the key goes with it.
    .PARAMETER KeyFile
        The public key file to add.
    .PARAMETER Title
        A title for the key.
    .PARAMETER AllowWrite
        Lets the key push, not just pull.
    .PARAMETER Repository
        The repository to add it to, in [HOST/]OWNER/REPO form. Omit it
        to use the current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$KeyFile,

        [string]$Title,

        [switch]$AllowWrite,

        [string]$Repository
    )

    $arguments = @('repo', 'deploy-key', 'add', $KeyFile)
    if ($Title) {
        $arguments += @('--title', $Title)
    }

    if ($AllowWrite) {
        $arguments += '--allow-write'
    }

    Invoke-GitHubCommand -Activity "Adding deploy key $KeyFile" -Arguments $arguments -Repository $Repository | Out-Null
}
