function Get-GitMergeBase {
    <#
    .SYNOPSIS
        Returns the commit SHA where two refs' histories last met, or
        $null when they share no history.
    .PARAMETER Ref1
        The first ref.
    .PARAMETER Ref2
        The second ref.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Ref1,

        [Parameter(Mandatory, Position = 1)]
        [string]$Ref2,

        [string]$RepoPath
    )

    $read = Invoke-GitCommand -Activity 'Finding the merge base' `
        -Arguments @('merge-base', $Ref1, $Ref2) -RepoPath $RepoPath -Tolerant
    if (-not $read.Ok) {
        return $null
    }

    return ($read.Output -join '').Trim()
}
