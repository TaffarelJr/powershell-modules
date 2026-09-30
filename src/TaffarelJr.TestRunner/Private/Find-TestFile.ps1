using namespace System.Management.Automation

function Find-TestFile {
    <#
    .SYNOPSIS
        Returns every *.Tests.ps1 under one or more folders whose name
        matches the filter and none of the exclusions, sorted by path,
        one at a time.
        A file under two of the folders is returned once.
    .DESCRIPTION
        Hidden files and folders are searched too - on Linux and macOS every
        name starting with a dot is hidden, and the same tree has to run the
        same files on every platform.
    .PARAMETER Path
        The folders to search, recursively.
    .PARAMETER Filter
        A file-system filter over the file name, without the .Tests.ps1
        suffix: * and ? only - brackets are not a character range.
    .PARAMETER Exclude
        Patterns over the file name, without the .Tests.ps1 suffix, in the
        same vocabulary as -Filter: * and ? only, brackets and backticks
        stand for themselves. Case does not matter. A file matching any one
        of them is left out; none at all leaves every file in.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Path,

        [string]$Filter = '*',

        [string[]]$Exclude = @()
    )

    $files = @(Get-ChildItem -LiteralPath $Path -Recurse -File -Force -Filter "$Filter.Tests.ps1")

    $options = [WildcardOptions]'IgnoreCase, CultureInvariant'
    $patterns = @(
        foreach ($entry in $Exclude) {
            $literal = $entry -replace '`', '``'
            $escaped = [WildcardPattern]::Escape($literal)
            $wildcard = $escaped -replace '`\*', '*' -replace '`\?', '?'
            [WildcardPattern]::new($wildcard, $options)
        }
    )

    $kept = @(
        foreach ($file in $files) {
            $name = $file.BaseName -replace '\.Tests$'
            $excluded = $false
            foreach ($pattern in $patterns) {
                if ($pattern.IsMatch($name)) {
                    $excluded = $true
                    break
                }
            }

            if (-not $excluded) {
                $file
            }
        }
    )

    return Select-UniqueFile -File $kept
}
