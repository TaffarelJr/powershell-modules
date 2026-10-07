function Resolve-GitConflict {
    <#
    .SYNOPSIS
        Resolves a conflicted path by keeping one side whole, then marks
        it resolved.
    .DESCRIPTION
        Checking out a side alone only updates the working tree; git
        still considers the path unmerged until it is re-staged. This
        does both steps, so the path is fully resolved afterward.

        Only unmerged paths are touched: a folder resolves the conflicts
        inside it and leaves every other file in it as it is, and a path with
        no conflict throws before anything changes, so an uncommitted edit is
        never replaced. Keeping a side that deleted the path is not something
        a checkout can do, and throws.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Path
        The conflicted path, or a folder of them, to resolve. A bare
        relative path, such as 'src/x.txt', is relative to the repository
        root, the way Get-GitConflict reports it, from whichever folder this
        runs in. A path that starts with '.' or '..', such as '.\x.txt', is
        relative to the folder this runs in (-RepoPath, else the current
        location), and an absolute path is used as it is. The path is
        literal - '*', '?' and '[' are part of the name, not a pattern - and a
        backslash is read as a forward slash. Accepted from the pipeline,
        including by property name, so
        'Get-GitConflict | Resolve-GitConflict -Side Ours' keeps one side
        of every conflict.
    .PARAMETER Side
        Which side to keep. In a merge, Ours is the current branch and
        Theirs the branch being merged in. During a rebase the meanings
        swap: Ours is the branch being rebased onto, Theirs the commit being
        replayed.
    .PARAMETER RepoPath
        The repo to act in. Omit it to use the current working directory.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.String
        A conflicted path, or an object with a Path, FullName or PSPath
        property.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Resolve-GitConflict -Path 'src/app.ps1' -Side Theirs

        Keeps the incoming side of one conflicted file and marks it resolved.
    .EXAMPLE
        Get-GitConflict | Resolve-GitConflict -Side Ours

        Keeps the current side of every conflicted file.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitConflict
    .LINK
        Resume-GitRebase
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'PSPath')]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateSet('Ours', 'Theirs')]
        [string]$Side,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
                $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Confirm')) {
                $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            $flag = "--$($Side.ToLowerInvariant())"
            $activity = "Keeping the $Side side of $Path"
            $pathspec = ConvertTo-GitPathspec -Path $Path -Activity $activity -RepoPath $RepoPath
            $root = Get-GitRepoLocation -Activity $activity -RepoPath $RepoPath
            $target = ConvertTo-GitFullPath -Path $Path -Root $root -RepoPath $RepoPath
            $conflicted = @(Get-GitUnmergedPath -Pathspec $pathspec -Activity $activity -RepoPath $RepoPath)
            if ($conflicted.Count -eq 0) {
                throw "$activity failed: -Path '$Path' has no conflict to resolve."
            }

            if (-not $PSCmdlet.ShouldProcess($target, "Keep the $Side side and mark it resolved")) {
                return
            }

            $inRepo = @{}
            if ($PSBoundParameters.ContainsKey('RepoPath')) {
                $inRepo.RepoPath = $RepoPath
            }

            # Only the unmerged paths: a checkout of any other replaces its uncommitted edits.
            $exact = @($conflicted | ForEach-Object { ":(top,literal)$_" })
            Invoke-GitCommand -Activity $activity `
                -Arguments (@('checkout', $flag, '--') + $exact) -RepoPath $RepoPath | Out-Null
            Add-GitChange -Path $conflicted @inRepo -WhatIf:$false -Confirm:$false
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
