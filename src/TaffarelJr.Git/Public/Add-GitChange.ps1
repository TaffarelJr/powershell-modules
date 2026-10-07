using namespace System.Collections.Generic

function Add-GitChange {
    <#
    .SYNOPSIS
        Stages changes.
    .DESCRIPTION
        Covers adds, modifications, and deletions alike (git's -A), not
        just new files.
    .PARAMETER Path
        A pathspec to scope staging to. Accepted from the pipeline,
        including by property name, so output from Get-ChildItem or
        Get-GitStatus can be piped straight in. Omit it to stage the
        entire working tree.
    .PARAMETER RepoPath
        The repo to stage in. Omit it to use the current working
        directory.
    #>
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string[]]$Path,

        [string]$RepoPath
    )

    begin {
        $paths = [List[string]]::new()
    }

    process {
        foreach ($p in $Path) {
            $paths.Add($p)
        }
    }

    end {
        $arguments = @('add', '-A')
        if ($paths.Count -gt 0) {
            $arguments += '--'
            $arguments += $paths
        }

        Invoke-GitCommand -Activity 'Staging changes' -Arguments $arguments -RepoPath $RepoPath | Out-Null
    }
}
