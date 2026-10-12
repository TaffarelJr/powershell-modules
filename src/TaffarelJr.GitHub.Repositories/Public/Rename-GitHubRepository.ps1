function Rename-GitHubRepository {
    <#
    .SYNOPSIS
        Renames a repository on GitHub.
    .DESCRIPTION
        Only the name changes; moving a repository to another owner is a
        transfer, which GitHub only offers through its website.
    .PARAMETER NewName
        The new name, without an owner.
    .PARAMETER Repository
        The repository to rename, in [HOST/]OWNER/REPO form. Omit it to
        use the current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$NewName,

        [string]$Repository
    )

    $arguments = @('repo', 'rename', $NewName, '--yes')
    Invoke-GitHubCommand -Activity "Renaming the repository to $NewName" -Arguments $arguments -Repository $Repository | Out-Null
}
