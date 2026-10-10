function Wait-GitHubWorkflowRun {
    <#
    .SYNOPSIS
        Waits for a workflow run to finish, then returns it.
    .DESCRIPTION
        gh's own watch reports a failed run through its exit code; that
        is ignored here, since the returned run carries its Conclusion
        for the caller to judge. A watch that could not start at all -
        no such run, no access - still surfaces when the finished run is
        read back. gh's watch does not work with a fine-grained personal
        access token, which cannot carry the checks:read permission it
        needs.
    .PARAMETER Id
        The run, by its database id.
    .PARAMETER Interval
        How many seconds to wait between polls. gh's default is 3.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    .OUTPUTS
        The finished run, as Get-GitHubWorkflowRun returns it - Status,
        Conclusion, Jobs, and the rest.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('DatabaseId')]
        [long]$Id,

        [int]$Interval,

        [string]$Repository
    )

    process {
        $arguments = @('run', 'watch', $Id)
        if ($Interval -gt 0) {
            $arguments += @('--interval', $Interval)
        }

        Invoke-GitHubCommand -Activity "Waiting for workflow run $Id" -Arguments $arguments -Repository $Repository -Tolerant | Out-Null
        return Get-GitHubWorkflowRun -Id $Id -Repository $Repository
    }
}
