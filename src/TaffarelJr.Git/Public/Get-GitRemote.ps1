function Get-GitRemote {
    <#
    .SYNOPSIS
        Returns every remote's name, or one remote's URL by -Name.
    .DESCRIPTION
        With -Name, $null rather than a throw when that remote does not
        exist - a missing remote is often itself a legitimate answer (for
        example, walking a chain of repos until one has no more
        upstream), not a failure.
    .PARAMETER Name
        The remote to read the URL of. Omit it to list every remote's name
        instead.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    #>
    param(
        [string]$Name,

        [string]$RepoPath
    )

    if (-not $Name) {
        return Invoke-GitCommand -Activity 'Listing remotes' -Arguments @('remote') -RepoPath $RepoPath
    }

    $read = Invoke-GitCommand -Activity "Reading the $Name remote" `
        -Arguments @('remote', 'get-url', $Name) -RepoPath $RepoPath -Tolerant
    if (-not $read.Ok) {
        return $null
    }

    return ($read.Output -join '').Trim()
}
