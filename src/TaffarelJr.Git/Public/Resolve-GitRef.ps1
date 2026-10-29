function Resolve-GitRef {
    <#
    .SYNOPSIS
        Resolves a ref to its full commit SHA, or $null when it does not
        exist. Doubles as the general "does this ref exist" check.
    .DESCRIPTION
        Always dereferences to a commit (even for an annotated tag, which
        is its own object distinct from the commit it marks), since a
        commit SHA is what nearly every other git operation actually
        wants. Only a ref that does not exist is $null: anything else git
        cannot answer, such as a folder that is no repository, throws.
    .PARAMETER Ref
        A branch, tag, HEAD, or any other git revision expression.
        Accepted from the pipeline to resolve several at once.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .INPUTS
        System.String
        A branch, tag, or other git revision expression.
    .OUTPUTS
        System.String
        The full SHA of the commit the ref names, or nothing when it does not
        exist.
    .EXAMPLE
        Resolve-GitRef -Ref 'main'

        Returns the full SHA of the commit main points at.
    .EXAMPLE
        'main', 'v1.2.0' | Resolve-GitRef

        Resolves two refs in one call.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitCommit
    .LINK
        Test-GitAncestor
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Ref,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            $read = Invoke-GitCommand -Activity "Resolving $Ref" `
                -Arguments @('rev-parse', '--verify', '--quiet', "$Ref^{commit}") -RepoPath $RepoPath -Tolerant

            # 1 is a ref that does not exist; anything else is git failing to
            # answer.
            if ($read.ExitCode -eq 1) {
                return
            }

            if (-not $read.Ok) {
                throw "Resolving $Ref failed (exit $($read.ExitCode)): $($read.Message)"
            }

            return ($read.Output -join '').Trim()
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
