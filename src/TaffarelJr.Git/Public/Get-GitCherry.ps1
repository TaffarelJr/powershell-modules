using namespace System.Collections.Generic

function Get-GitCherry {
    <#
    .SYNOPSIS
        Compares two branches by patch content rather than commit SHA,
        and returns which of -Upstream's commits -Base is still missing.
    .DESCRIPTION
        Immune to a prior rebase changing commit SHAs, unlike
        Compare-GitBranch - a commit already applied under a different
        SHA (because -Upstream was rebased since) is correctly reported
        as already present, not as missing.
    .PARAMETER Base
        The branch to check for missing commits.
    .PARAMETER Upstream
        The branch whose commits -Base should already have.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object per commit of -Upstream that -Base lacks by SHA: Status, '+'
        when -Base is missing its patch and '-' when an equivalent patch is
        already there, and Hash.
    .EXAMPLE
        Get-GitCherry -Base 'release' -Upstream 'main'

        Lists the commits of main whose patches release does not have yet.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Compare-GitBranch
    .LINK
        Get-GitLog
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
        [string]$Base,

        [Parameter(Mandatory, Position = 1)]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Upstream,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $out = Invoke-GitCommand -Activity 'Comparing patches' `
            -Arguments @('cherry', $Base, $Upstream) -RepoPath $RepoPath

        $results = [List[object]]::new()
        foreach ($line in $out) {
            if ($line -notmatch '^([+-])\s+([0-9a-f]+)') {
                continue
            }

            $results.Add([PSCustomObject]@{
                    Status = $Matches[1]
                    Hash   = $Matches[2]
                })
        }

        return $results
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
