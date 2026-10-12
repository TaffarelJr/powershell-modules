function Save-GitHubWorkflowRunArtifact {
    <#
    .SYNOPSIS
        Downloads and extracts the artifacts of a workflow run.
    .DESCRIPTION
        Each artifact extracts into its own folder under -Destination,
        named after it - except a single named artifact, which gh
        extracts straight into -Destination. Without -Id, gh takes the
        most recent artifact of each given name across the repository's
        runs; since a later run can overwrite an artifact, name the run
        when it matters which one.
    .PARAMETER Id
        The run, by its database id. Omit it to search every run.
    .PARAMETER Name
        Downloads only artifacts with one of these exact names.
    .PARAMETER Pattern
        Downloads only artifacts whose name matches one of these globs.
    .PARAMETER Destination
        The folder to extract into. gh's default is the current
        directory.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Id,

        [string[]]$Name,

        [string[]]$Pattern,

        [string]$Destination,

        [string]$Repository
    )

    $arguments = @('run', 'download')
    if ($Id) {
        $arguments += $Id
    }

    foreach ($artifact in $Name) {
        $arguments += @('--name', $artifact)
    }

    foreach ($glob in $Pattern) {
        $arguments += @('--pattern', $glob)
    }

    if ($Destination) {
        $arguments += @('--dir', $Destination)
    }

    Invoke-GitHubCommand -Activity 'Downloading workflow run artifacts' -Arguments $arguments -Repository $Repository | Out-Null
}
