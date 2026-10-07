using namespace System.Collections.Generic

function Get-GitLog {
    <#
    .SYNOPSIS
        Returns commit history as structured objects.
    .DESCRIPTION
        Parsed from a custom --format using the ASCII unit and record
        separators (0x1F, 0x1E) rather than visible punctuation, so a
        multi-paragraph commit body can never be mistaken for a field
        boundary.
    .PARAMETER Range
        A git revision range (for example 'main..HEAD'), or a single ref
        to start from. Omit it to start from HEAD.
    .PARAMETER Count
        Limits how many commits are returned.
    .PARAMETER Path
        Scopes the log to commits touching this path.
    .PARAMETER Reverse
        Returns the oldest matching commit first instead of the newest.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .OUTPUTS
        One object per commit: Hash, Author, Email, Date, Subject, Body.
    #>
    param(
        [string]$Range,

        [int]$Count,

        [string]$Path,

        [switch]$Reverse,

        [string]$RepoPath
    )

    $format = '%H%x1f%an%x1f%ae%x1f%aI%x1f%s%x1f%b%x1e'
    $arguments = @('log', "--format=$format")
    if ($Reverse) {
        $arguments += '--reverse'
    }

    if ($Count -gt 0) {
        $arguments += "-$Count"
    }

    if ($Range) {
        $arguments += $Range
    }

    if ($Path) {
        $arguments += @('--', $Path)
    }

    $out = Invoke-GitCommand -Activity 'Reading commit history' -Arguments $arguments -RepoPath $RepoPath
    $text = $out -join "`n"
    $entries = @($text -split "`u{1E}" | Where-Object { $_.Trim("`n", "`r") })

    $results = [List[object]]::new()
    foreach ($entry in $entries) {
        $fields = $entry.TrimStart("`n", "`r") -split "`u{1F}"
        if ($fields.Count -lt 6) {
            continue
        }

        $results.Add([PSCustomObject]@{
                Hash    = $fields[0]
                Author  = $fields[1]
                Email   = $fields[2]
                Date    = [DateTimeOffset]$fields[3]
                Subject = $fields[4]
                Body    = $fields[5].Trim("`n", "`r")
            })
    }

    return , @($results)
}
