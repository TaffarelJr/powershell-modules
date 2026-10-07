function Resolve-GitRef {
    <#
    .SYNOPSIS
        Resolves a ref to its full commit SHA, or $null when it does not
        exist. Doubles as the general "does this ref exist" check.
    .DESCRIPTION
        Always dereferences to a commit (even for an annotated tag, which
        is its own object distinct from the commit it marks), since a
        commit SHA is what nearly every other git operation actually
        wants.
    .PARAMETER Ref
        A branch, tag, HEAD, or any other git revision expression.
        Accepted from the pipeline to resolve several at once.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$Ref,

        [string]$RepoPath
    )

    process {
        $read = Invoke-GitCommand -Activity "Resolving $Ref" `
            -Arguments @('rev-parse', '--verify', '--quiet', "$Ref^{commit}") -RepoPath $RepoPath -Tolerant
        if (-not $read.Ok) {
            return $null
        }

        return ($read.Output -join '').Trim()
    }
}
