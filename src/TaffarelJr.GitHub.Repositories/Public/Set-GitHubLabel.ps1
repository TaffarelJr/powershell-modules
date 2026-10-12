function Set-GitHubLabel {
    <#
    .SYNOPSIS
        Changes a label's name, color, or description.
    .PARAMETER Name
        The label's current name.
    .PARAMETER NewName
        The label's new name.
    .PARAMETER Color
        The label's new color, as six hex digits.
    .PARAMETER Description
        The label's new description.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [string]$NewName,

        [string]$Color,

        [string]$Description,

        [string]$Repository
    )

    $arguments = @('label', 'edit', $Name)
    if ($NewName) {
        $arguments += @('--name', $NewName)
    }

    if ($Color) {
        $arguments += @('--color', $Color)
    }

    if ($Description) {
        $arguments += @('--description', $Description)
    }

    Invoke-GitHubCommand -Activity "Editing label $Name" -Arguments $arguments -Repository $Repository | Out-Null
}
