function Test-GitPath {
    <#
    .SYNOPSIS
        Returns whether a path exists in git, either currently tracked or
        at a specific historical ref.
    .DESCRIPTION
        Both checks read the path the same way, so the same path gives the
        same answer with or without -Ref. A ref that does not exist, or a
        folder that is no repository, throws instead of reading as $false.
    .PARAMETER Path
        The path to check. A bare relative path, such as 'src/x.txt', is
        relative to the repository root, the way Get-GitStatus reports it,
        from whichever folder this runs in. A path that starts with '.' or
        '..', such as '.\x.txt', is relative to the folder this runs in
        (-RepoPath, else the current location), and an absolute path is used
        as it is. The path is literal - '*', '?' and '[' are part of the
        name, not a pattern - and a backslash is read as a forward slash. A
        folder exists when a file under it does.
    .PARAMETER Ref
        A historical ref to check the path at, instead of the current
        index. Omit it to check whether the path is tracked right now.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.Boolean
        $true when the path exists in git, $false when it does not.
    .EXAMPLE
        Test-GitPath -Path 'src/app.ps1'

        Tells whether git tracks the file right now.
    .EXAMPLE
        Test-GitPath -Path 'src/app.ps1' -Ref 'v1.0.0'

        Tells whether the file existed at a tag.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitStatus
    .LINK
        Get-GitRename
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Ref,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $pathspec = ConvertTo-GitPathspec -Path $Path -Activity "Checking $Path" -RepoPath $RepoPath
        if ($Ref) {
            $listing = Invoke-GitCommand -Activity "Checking $Path at $Ref" `
                -Arguments @('ls-tree', $Ref, '--', $pathspec) -RepoPath $RepoPath
            return $null -ne $listing
        }

        $read = Invoke-GitCommand -Activity "Checking $Path" `
            -Arguments @('ls-files', '--error-unmatch', '--', $pathspec) -RepoPath $RepoPath -Tolerant

        # 0 is tracked and 1 is not; anything else is git failing to answer.
        if ($read.ExitCode -gt 1) {
            throw "Checking $Path failed (exit $($read.ExitCode)): $($read.Message)"
        }

        return $read.Ok
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
