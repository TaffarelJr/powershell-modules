function Get-TokenCandidate {
    <#
    .SYNOPSIS
        Returns every item under a tree that a token pass is allowed to touch.
    .DESCRIPTION
        Not exported. A subtree that could not be listed
        is recorded rather than silently dropped,
        so a partial pass cannot pass for a complete one.
    .OUTPUTS
        A pscustomobject with Item (the candidate items)
        and Warning (one line per subtree that could not be listed).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Exclude
    )

    $root = (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\', '/')
    $escaped = ($Exclude | ForEach-Object { [regex]::Escape($_) }) -join '|'

    # Matched against each path RELATIVE to the root. Against the absolute path,
    # a tree that merely lives under a folder named 'bin' or 'scripts'
    # would exclude its own entire tree and report finding nothing.
    $excludePattern = "(^|[\\/])($escaped)([\\/]|`$)"

    $items = Get-ChildItem -LiteralPath $root -Recurse -Force `
        -ErrorAction SilentlyContinue -ErrorVariable failures

    $warnings = @($failures | ForEach-Object {
            "Not searched: $($_.TargetObject) - $($_.Exception.Message)"
        })

    $candidates = @($items | Where-Object {
            $_.FullName.Substring($root.Length) -notmatch $excludePattern
        })

    return [PSCustomObject]@{
        Item    = $candidates
        Warning = $warnings
    }
}
