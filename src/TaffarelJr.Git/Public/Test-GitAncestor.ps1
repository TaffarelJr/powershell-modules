function Test-GitAncestor {
    <#
    .SYNOPSIS
        Returns whether one ref is an ancestor of another (or the same
        commit).
    .DESCRIPTION
        Throws for a ref that does not exist: only a clean "no" is
        $false, never an error read as one.
    .PARAMETER Ancestor
        The ref that might be the ancestor.
    .PARAMETER Descendant
        The ref that might descend from it.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.Boolean
        $true when -Ancestor is an ancestor of -Descendant, or the same commit.
    .EXAMPLE
        Test-GitAncestor -Ancestor 'v1.2.0' -Descendant 'main'

        Tells whether main contains the commit the tag points at.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitMergeBase
    .LINK
        Compare-GitBranch
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Ancestor,

        [Parameter(Mandatory, Position = 1)]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Descendant,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $read = Invoke-GitCommand -Activity 'Checking ancestry' `
            -Arguments @('merge-base', '--is-ancestor', $Ancestor, $Descendant) -RepoPath $RepoPath -Tolerant

        # 0 is yes and 1 is no; anything else is git failing to answer.
        if ($read.ExitCode -gt 1) {
            throw "Checking whether $Ancestor is an ancestor of $Descendant failed" +
            " (exit $($read.ExitCode)): $($read.Message)"
        }

        return $read.Ok
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
