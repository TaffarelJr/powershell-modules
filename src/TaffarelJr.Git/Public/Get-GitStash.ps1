using namespace System.Collections.Generic

function Get-GitStash {
    <#
    .SYNOPSIS
        Returns every stashed entry.
    .DESCRIPTION
        Lists the stash newest first, each entry with the index
        Restore-GitStash takes and the message it was saved with. A
        repository with no stash returns nothing.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object per stash, newest first: Index, for Restore-GitStash, and
        Message.
    .EXAMPLE
        Get-GitStash

        Lists the stashed entries of the current repository.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Save-GitStash
    .LINK
        Restore-GitStash
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseOutputTypeCorrectly',
        '',
        Justification = 'PowerShell unrolls the list this builds, so the output is its elements.')]
    param(
        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $out = Invoke-GitCommand -Activity 'Listing stashes' `
            -Arguments @('stash', 'list', '--format=%gd%x1f%s') -RepoPath $RepoPath

        $results = [List[object]]::new()
        foreach ($line in $out) {
            $parts = $line -split "`u{1F}"
            if ($parts.Count -lt 2) {
                continue
            }

            if ($parts[0] -notmatch '\{(\d+)\}') {
                continue
            }

            $results.Add([PSCustomObject]@{
                    Index   = [int]$Matches[1]
                    Message = $parts[1]
                })
        }

        return $results
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
