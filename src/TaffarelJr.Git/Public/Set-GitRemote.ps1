function Set-GitRemote {
    <#
    .SYNOPSIS
        Points a remote at a URL, adding it if it is new or repointing it
        if it already exists.
    .PARAMETER Name
        The remote to add or repoint.
    .PARAMETER Url
        The URL to set it to.
    .PARAMETER RepoPath
        The repo to set it in. Omit it to use the current working
        directory.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [string]$Url,

        [string]$RepoPath
    )

    $remotes = Invoke-GitCommand -Activity 'Listing remotes' -Arguments @('remote') -RepoPath $RepoPath
    if ($remotes -contains $Name) {
        Invoke-GitCommand -Activity "Repointing the $Name remote" `
            -Arguments @('remote', 'set-url', $Name, $Url) -RepoPath $RepoPath | Out-Null
        return
    }

    Invoke-GitCommand -Activity "Adding the $Name remote" `
        -Arguments @('remote', 'add', $Name, $Url) -RepoPath $RepoPath | Out-Null
}
