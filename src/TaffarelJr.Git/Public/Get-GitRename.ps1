using namespace System.Collections.Generic

function Get-GitRename {
    <#
    .SYNOPSIS
        Returns every file renamed between two refs, as old/new path
        pairs.
    .DESCRIPTION
        A rename detected by content similarity, not by name alone. A
        step that reacts to a deleted path should check this before
        treating it as a real deletion - otherwise a plain rename reads as
        a delete-and-add, which for a generated or synced file can mean
        silently dropping it on the deleted side instead of carrying it
        forward under its new name.

        Read NUL-separated, so a path git would otherwise quote and escape
        comes back as the name on disk. A ref named like a file or folder
        is still read as a ref.
    .PARAMETER FromRef
        The earlier ref.
    .PARAMETER ToRef
        The later ref.
    .PARAMETER Path
        Keeps only the renames that start or end at this path, or under it
        when it is a folder, matched case-sensitively, as git names paths. A
        bare relative path, such as 'docs/a.md', is relative to the
        repository root. A path that starts with '.' or '..', such as
        '.\docs', is relative to the folder this runs in (-RepoPath, else
        the current location), and an absolute path is used as it is; either
        must lie inside the repository's working tree. A backslash is read
        as a forward slash. Filtered here, after git has looked at the whole
        range: handed to git as a pathspec it would hide the other side of
        every rename, and none would be found.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object per rename: OldPath and NewPath.
    .EXAMPLE
        Get-GitRename -FromRef 'v1.0.0' -ToRef 'HEAD'

        Lists every file renamed between a tag and HEAD.
    .EXAMPLE
        Get-GitRename -FromRef 'main' -ToRef 'feature/x' -Path 'docs'

        Lists only the renames that start or end under the docs folder.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitDiff
    .LINK
        Move-GitFile
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseOutputTypeCorrectly',
        '',
        Justification = 'PowerShell unrolls the list this builds, so the output is its elements.')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$FromRef,

        [Parameter(Mandatory, Position = 1)]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$ToRef,

        [string]$Path,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $arguments = @('diff', '--name-status', '-M', '--diff-filter=R', '-z', $FromRef, $ToRef, '--')
        $out = Invoke-GitCommand -Activity 'Reading renames' -Arguments $arguments -RepoPath $RepoPath
        $fields = @(($out -join "`n") -split "`0" | Where-Object { $_ })

        $scope = ''
        $full = if ($Path) { Resolve-GitPath -Path $Path -RepoPath $RepoPath }
        if ($full) {
            $inRepo = @{}
            if ($PSBoundParameters.ContainsKey('RepoPath')) {
                $inRepo.RepoPath = $RepoPath
            }

            $root = Get-GitRepositoryRoot @inRepo
            if (-not $root) {
                throw "Reading renames failed: -Path '$Path' needs a working tree to be relative to," +
                ' and there is none here. Give it relative to the repository root.'
            }

            # git names the path's place in the repository itself, from the
            # nearest folder that exists, so a junction or symbolic link on the
            # way still leads inside.
            $folder = $full
            $rest = [List[string]]::new()
            while ($folder -and -not (Test-Path -LiteralPath $folder -PathType Container)) {
                $rest.Insert(0, (Split-Path -Path $folder -Leaf))
                $folder = Split-Path -Path $folder -Parent
            }

            # The repository and working tree already found are named outright,
            # since a -C into the path's folder would read a relative GIT_DIR, or
            # a linked worktree's GIT_DIR with no GIT_WORK_TREE, against it.
            $gitDir = Get-GitDirectory @inRepo
            $located = if ($folder) {
                Invoke-GitCommand -Activity 'Reading renames' `
                    -Arguments @("--git-dir=$gitDir", "--work-tree=$root", '-C', $folder,
                        'rev-parse', '--is-inside-work-tree', '--show-prefix') `
                    -RepoPath $RepoPath -Tolerant
            }

            $lines = @(if ($located -and $located.Ok) { $located.Output })
            $inside = $lines.Count -gt 0 -and $lines[0] -ceq 'true'
            if (-not $inside) {
                throw "Reading renames failed: -Path '$Path' is outside the repository at '$root'."
            }

            $prefix = if ($lines.Count -gt 1) { $lines[1] } else { '' }
            $scope = ConvertTo-GitRootPath -Path "$prefix/$($rest -join '/')" -Activity 'Reading renames'
        }
        elseif ($Path) {
            $scope = ConvertTo-GitRootPath -Path $Path -Activity 'Reading renames'
        }

        $inScope = {
            param($candidate)
            -not $scope -or $candidate -ceq $scope -or $candidate.StartsWith("$scope/", [StringComparison]::Ordinal)
        }

        # Each rename is three fields: the status with its similarity, then the
        # old path, then the new.
        $results = [List[object]]::new()
        for ($i = 0; $i + 2 -lt $fields.Count; $i += 3) {
            $old = $fields[$i + 1]
            $new = $fields[$i + 2]
            if (-not (& $inScope $old) -and -not (& $inScope $new)) {
                continue
            }

            $results.Add([PSCustomObject]@{
                    OldPath = $old
                    NewPath = $new
                })
        }

        return $results
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
