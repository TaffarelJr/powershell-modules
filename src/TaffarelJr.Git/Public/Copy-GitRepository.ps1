function Copy-GitRepository {
    <#
    .SYNOPSIS
        Clones a repository.
    .PARAMETER Url
        The repository to clone.
    .PARAMETER Destination
        Where to clone it to.
    .PARAMETER Branch
        Checks out this branch instead of the remote's default.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Url,

        [Parameter(Mandatory, Position = 1)]
        [string]$Destination,

        [string]$Branch
    )

    $arguments = @('clone')
    if ($Branch) {
        $arguments += @('--branch', $Branch)
    }

    $arguments += @($Url, $Destination)
    Invoke-GitCommand -Activity "Cloning $Url" -Arguments $arguments | Out-Null
}
