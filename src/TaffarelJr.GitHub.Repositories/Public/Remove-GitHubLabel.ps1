function Remove-GitHubLabel {
    <#
    .SYNOPSIS
        Deletes a label from a repository.
    .PARAMETER Name
        The label's name.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$Repository
    )

    process {
        $arguments = @('label', 'delete', $Name, '--yes')
        Invoke-GitHubCommand -Activity "Deleting label $Name" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
