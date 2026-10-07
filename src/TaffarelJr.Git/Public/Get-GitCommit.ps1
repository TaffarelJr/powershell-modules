function Get-GitCommit {
    <#
    .SYNOPSIS
        Returns one commit's details, or $null when the ref does not
        resolve to a commit.
    .DESCRIPTION
        Only a ref that does not exist is $null: anything else git cannot
        answer, such as a folder that is no repository, throws.
    .PARAMETER Ref
        The commit to describe. Defaults to HEAD.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        The commit, as Get-GitLog returns one: Hash, Author, Email, Date,
        Subject and Body. Nothing is returned when the ref names no commit.
    .EXAMPLE
        Get-GitCommit

        Returns the commit HEAD points at.
    .EXAMPLE
        Get-GitCommit -Ref 'v1.2.0' -RepoPath 'C:\src\project'

        Returns the commit a tag points at, in another repository.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitLog
    .LINK
        Resolve-GitRef
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Ref = 'HEAD',

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $inRepo = @{}
        if ($PSBoundParameters.ContainsKey('RepoPath')) {
            $inRepo.RepoPath = $RepoPath
        }

        # Resolved first, to the commit itself, rather than letting Get-GitLog's
        # own git log call fail: an invalid range throws there, where $null is the
        # expected answer here.
        $hash = Resolve-GitRef -Ref $Ref @inRepo
        if (-not $hash) {
            return
        }

        $result = @(Get-GitLog -Range $hash -Count 1 @inRepo)
        return $result[0]
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
