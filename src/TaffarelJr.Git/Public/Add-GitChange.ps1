using namespace System.Collections.Generic

function Add-GitChange {
    <#
    .SYNOPSIS
        Stages changes.
    .DESCRIPTION
        Covers adds, modifications, and deletions alike (git's -A), not
        just new files.

        Stages the whole working tree only when no path was mentioned at
        all. Paths that come to nothing - a pipeline that turned out to be
        empty, or an empty -Path - stage nothing, so
        'Get-GitStatus | Where-Object ... | Add-GitChange' never falls back
        to staging everything when nothing matched.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Path
        The files or folders to stage. A bare relative path, such as
        'src/x.txt', is relative to the repository root, the way
        Get-GitStatus reports it, from whichever folder this runs in. A path
        that starts with '.' or '..', such as '.\x.txt' or '.', is relative
        to the folder this runs in (-RepoPath, else the current location),
        and an absolute path, such as Get-ChildItem's FullName, is used as it
        is. Each path is literal - '*', '?' and '[' are part of the name, not
        a pattern - and a backslash is read as a forward slash. Accepted from
        the pipeline, including by property name, so output from
        Get-ChildItem or Get-GitStatus can be piped straight in. Omit it, and
        pipe nothing, to stage the entire working tree.
    .PARAMETER RepoPath
        The repo to stage in. Omit it to use the current working
        directory.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.String
        A path to stage, or an object with a Path, FullName or PSPath property,
        such as the output of Get-ChildItem or Get-GitStatus.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Add-GitChange -Path 'src/app.ps1', 'docs/README.md'

        Stages two files, each named relative to the repository root.
    .EXAMPLE
        Get-GitStatus | Where-Object Status -Like '*M*' | Add-GitChange

        Stages only the modified files. A pipeline that matches nothing stages
        nothing.
    .EXAMPLE
        Add-GitChange -RepoPath 'C:\src\project'

        Stages every change in the working tree of the repository at that path.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitStatus
    .LINK
        New-GitCommit
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'PSPath')]
        [string[]]$Path,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    begin {
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

            $pathspecs = [List[string]]::new()
            $given = [List[string]]::new()
            $stageAll = -not $PSBoundParameters.ContainsKey('Path') -and -not $MyInvocation.ExpectingInput
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }

    process {
        try {
            foreach ($p in $Path) {
                $pathspecs.Add((ConvertTo-GitPathspec -Path $p -Activity 'Staging changes' -RepoPath $RepoPath))
                $given.Add($p)
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }

    end {
        try {
            if (-not $stageAll -and $pathspecs.Count -eq 0) {
                return
            }

            $arguments = @('add', '-A')
            $root = Get-GitRepoLocation -Activity 'Staging changes' -RepoPath $RepoPath
            $target = $root
            $action = 'Stage all changes'
            if (-not $stageAll) {
                $arguments += '--'
                $arguments += $pathspecs
                $fullPaths = foreach ($p in $given) {
                    ConvertTo-GitFullPath -Path $p -Root $root -RepoPath $RepoPath
                }

                $target = $fullPaths -join ', '
                $action = 'Stage changes'
            }

            if (-not $PSCmdlet.ShouldProcess($target, $action)) {
                return
            }

            Invoke-GitCommand -Activity 'Staging changes' -Arguments $arguments -RepoPath $RepoPath | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
