function New-GitHubLabel {
    <#
    .SYNOPSIS
        Creates a label, or with -Force updates one that already exists.
    .PARAMETER Name
        The label's name.
    .PARAMETER Color
        The label's color, as six hex digits. gh picks one at random
        when omitted.
    .PARAMETER Description
        The label's description.
    .PARAMETER Force
        Updates the color and description of a label that already
        exists, instead of failing.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [string]$Color,

        [string]$Description,

        [switch]$Force,

        [string]$Repository
    )

    $arguments = @('label', 'create', $Name)
    if ($Color) {
        $arguments += @('--color', $Color)
    }

    if ($Description) {
        $arguments += @('--description', $Description)
    }

    if ($Force) {
        $arguments += '--force'
    }

    Invoke-GitHubCommand -Activity "Creating label $Name" -Arguments $arguments -Repository $Repository | Out-Null
}
