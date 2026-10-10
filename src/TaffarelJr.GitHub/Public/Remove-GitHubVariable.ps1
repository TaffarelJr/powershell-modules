function Remove-GitHubVariable {
    <#
    .SYNOPSIS
        Deletes an Actions variable at a repository, environment, or
        organization level.
    .PARAMETER Name
        The variable's name.
    .PARAMETER Environment
        Deletes a deployment environment's variable instead of the
        repository's own.
    .PARAMETER Organization
        Deletes an organization's variable instead of a repository's.
    .PARAMETER Repository
        The repository to delete it from, in [HOST/]OWNER/REPO form. Omit
        it to use the current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$Name,

        [string]$Environment,

        [string]$Organization,

        [string]$Repository
    )

    process {
        $arguments = @('variable', 'delete', $Name)
        if ($Environment) {
            $arguments += @('--env', $Environment)
        }

        if ($Organization) {
            $arguments += @('--org', $Organization)
        }

        Invoke-GitHubCommand -Activity "Deleting variable $Name" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
