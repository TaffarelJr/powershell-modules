function Get-GitMergeBase {
    <#
    .SYNOPSIS
        Returns the commit SHA where two refs' histories last met, or
        $null when they share no history.
    .DESCRIPTION
        Throws for a ref that does not exist, as Test-GitAncestor does:
        only histories that never met are $null, never an error read as
        that.
    .PARAMETER Ref1
        The first ref.
    .PARAMETER Ref2
        The second ref.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.String
        The SHA of the commit where the two histories last met, or nothing when
        they share none.
    .EXAMPLE
        Get-GitMergeBase -Ref1 'main' -Ref2 'feature/x'

        Returns the commit where feature/x branched off main.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Test-GitAncestor
    .LINK
        Get-GitRootCommit
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Ref1,

        [Parameter(Mandatory, Position = 1)]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Ref2,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $read = Invoke-GitCommand -Activity 'Finding the merge base' `
            -Arguments @('merge-base', $Ref1, $Ref2) -RepoPath $RepoPath -Tolerant

        # 1 is no shared history; anything else is git failing to answer.
        if ($read.ExitCode -eq 1) {
            return
        }

        if (-not $read.Ok) {
            throw "Finding the merge base of $Ref1 and $Ref2 failed (exit $($read.ExitCode)): $($read.Message)"
        }

        return ($read.Output -join '').Trim()
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
