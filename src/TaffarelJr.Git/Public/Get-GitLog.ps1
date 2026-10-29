using namespace System.Collections.Generic

function Get-GitLog {
    <#
    .SYNOPSIS
        Returns commit history as structured objects.
    .DESCRIPTION
        Parsed from a custom --format whose fields and commits are each
        ended by a NUL, the one character a commit message cannot hold, so
        no subject or body, whatever it contains, can be mistaken for a field
        boundary. Signatures are not shown and the text is UTF-8 whatever
        log.showSignature and i18n.logOutputEncoding say, since either would
        alter what is parsed.

        A repository with no commits yet, bare or not, has an empty history:
        nothing is returned, and nothing is thrown. A ref named like a file
        or folder is still read as a ref.
    .PARAMETER Range
        A git revision range (for example 'main..HEAD'), or a single ref
        to start from. Omit it to start from HEAD.
    .PARAMETER Count
        Limits how many commits are returned. 0, the default, is no limit.
    .PARAMETER Path
        Scopes the log to commits touching this path. A bare relative path,
        such as 'src/x.txt', is relative to the repository root, from
        whichever folder this runs in. A path that starts with '.' or '..',
        such as '.\x.txt', is relative to the folder this runs in (-RepoPath,
        else the current location), and an absolute path is used as it is.
        The path is literal - '*', '?' and '[' are part of the name, not a
        pattern - and a backslash is read as a forward slash.
    .PARAMETER Reverse
        Returns the oldest matching commit first instead of the newest.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object per commit: Hash, Author, Email, Date (a DateTimeOffset),
        Subject and Body.
    .EXAMPLE
        Get-GitLog -Count 10

        Returns the ten newest commits of the current branch.
    .EXAMPLE
        Get-GitLog -Range 'v1.0.0..HEAD' -Path 'src/app.ps1' -Reverse

        Returns the commits since a tag that touched one file, oldest first.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitCommit
    .LINK
        Get-GitDiff
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseOutputTypeCorrectly',
        '',
        Justification = 'PowerShell unrolls the list this builds, so the output is its elements.')]
    param(
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Range,

        [ValidateRange('NonNegative')]
        [int]$Count,

        [string]$Path,

        [switch]$Reverse,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $format = '%H%x00%an%x00%ae%x00%aI%x00%s%x00%b'
        $arguments = @('log', '-z', "--format=$format", '--no-show-signature', '--encoding=UTF-8')
        if ($Reverse) {
            $arguments += '--reverse'
        }

        if ($Count -gt 0) {
            $arguments += "-$Count"
        }

        if ($Range) {
            $arguments += $Range
        }

        $arguments += '--'
        if ($Path) {
            $arguments += ConvertTo-GitPathspec -Path $Path -Activity 'Reading commit history' -RepoPath $RepoPath
        }

        $read = Invoke-GitCommand -Activity 'Reading commit history' -Arguments $arguments -RepoPath $RepoPath -Tolerant
        if (-not $read.Ok) {
            $inRepo = @{}
            if ($PSBoundParameters.ContainsKey('RepoPath')) {
                $inRepo.RepoPath = $RepoPath
            }

            $noCommitsYet = -not $Range -and (Get-GitDirectory @inRepo) -and -not (Resolve-GitRef -Ref 'HEAD' @inRepo)
            if ($noCommitsYet) {
                return
            }

            throw "Reading commit history failed (exit $($read.ExitCode)): $($read.Message)"
        }

        # -z ends each commit with a NUL as well, so the fields run on as one list, six to a commit.
        $fields = ($read.Output -join "`n") -split "`0"

        $results = [List[object]]::new()
        for ($i = 0; $i + 5 -lt $fields.Count; $i += 6) {
            $results.Add([PSCustomObject]@{
                    Hash    = $fields[$i]
                    Author  = $fields[$i + 1]
                    Email   = $fields[$i + 2]
                    Date    = [DateTimeOffset]$fields[$i + 3]
                    Subject = $fields[$i + 4]
                    Body    = $fields[$i + 5].Trim("`n", "`r")
                })
        }

        return $results
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
