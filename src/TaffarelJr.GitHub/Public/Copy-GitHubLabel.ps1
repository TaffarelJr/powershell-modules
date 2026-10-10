function Copy-GitHubLabel {
    <#
    .SYNOPSIS
        Copies every label from one repository into another.
    .DESCRIPTION
        Labels the destination already has are skipped unless -Force
        overwrites them; labels only the destination has are left alone.
    .PARAMETER Source
        The repository to copy labels from, in [HOST/]OWNER/REPO form.
    .PARAMETER Force
        Overwrites a destination label that already exists.
    .PARAMETER Repository
        The repository to copy labels into, in [HOST/]OWNER/REPO form.
        Omit it to use the current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Source,

        [switch]$Force,

        [string]$Repository
    )

    $arguments = @('label', 'clone', $Source)
    if ($Force) {
        $arguments += '--force'
    }

    Invoke-GitHubCommand -Activity "Copying labels from $Source" -Arguments $arguments -Repository $Repository | Out-Null
}
