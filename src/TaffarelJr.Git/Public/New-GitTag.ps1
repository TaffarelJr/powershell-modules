function New-GitTag {
    <#
    .SYNOPSIS
        Creates a tag.
    .PARAMETER Name
        The tag name.
    .PARAMETER Ref
        The commit to tag. Defaults to HEAD.
    .PARAMETER Message
        Creates an annotated tag with this message, instead of a
        lightweight one.
    .PARAMETER RepoPath
        The repo to tag. Omit it to use the current working directory.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [string]$Ref,

        [string]$Message,

        [string]$RepoPath
    )

    $arguments = @('tag')
    if ($Message) {
        $arguments += @('-a', '-m', $Message)
    }

    $arguments += $Name
    if ($Ref) {
        $arguments += $Ref
    }

    Invoke-GitCommand -Activity "Creating tag $Name" -Arguments $arguments -RepoPath $RepoPath | Out-Null
}
