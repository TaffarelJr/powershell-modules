function Remove-GitHubDeployKey {
    <#
    .SYNOPSIS
        Deletes a deploy key from a repository.
    .DESCRIPTION
        Deletes without asking by default; -Confirm asks first. A key piped
        in from Get-GitHubDeployKey is deleted by its Id from the repository
        it was listed from (on its own host; one listed without a host is
        on gh's default host, the one GH_HOST names, else github.com); a
        -Repository naming another repository or host throws, so a key of
        the same id there is not deleted - as does one beside a key listed
        from the current directory's repository.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Id
        The key's id, as Get-GitHubDeployKey reports it.
    .PARAMETER Repository
        The repository to delete it from, in [HOST/]OWNER/REPO form or as a
        URL, or a repository object. Omit it to use the current
        directory's repository. A -Repository given as $null throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Int64
        A key's id, or a key from Get-GitHubDeployKey, read by its Id and
        Repository properties.
    .OUTPUTS
        None.
    .EXAMPLE
        Remove-GitHubDeployKey -Id 12345 -Repository 'OWNER/REPO'

        Deletes deploy key 12345 from OWNER/REPO.
    .EXAMPLE
        Get-GitHubDeployKey -Repository 'OWNER/REPO' |
            Where-Object Title -EQ 'CI' |
            Remove-GitHubDeployKey

        Deletes the deploy key titled CI from OWNER/REPO.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Get-GitHubDeployKey
    .LINK
        Add-GitHubDeployKey
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [long]::MaxValue)]
        [long]$Id,

        [Parameter(ValueFromPipelineByPropertyName)]
        [object]$Repository
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

            $given = $PSBoundParameters.ContainsKey('Repository')
            $named = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
            $shownNamed = Hide-UrlCredential -Text $named
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $reference = ConvertTo-GitHubRepositoryReference -Repository $Repository
            $listed = $null
            if ($MyInvocation.ExpectingInput) {
                $listed = $_
            }

            $listedHere = $null -ne $listed -and $listed -isnot [ValueType] -and $listed -isnot [string]
            if ($given -and $listedHere -and $listed.PSObject.Properties['Repository']) {
                if ($null -eq $listed.Repository) {
                    throw "Deploy key $Id was listed from the current directory's repository, but -Repository names" +
                    " ${shownNamed}: leave -Repository off, or list the key with -Repository."
                }

                $compare = @{
                    Item       = "Deploy key $Id"
                    Origin     = ConvertTo-GitHubRepositoryReference -Repository $listed.Repository
                    Repository = $named
                    PassThru   = $true
                }
                $reference = Assert-GitHubSameRepository @compare
                $namedHost = Get-GitHubReferenceHost -Reference $named -Named
                $originHost = Get-GitHubReferenceHost -Reference $compare['Origin']
                if ($namedHost -and $namedHost -ne $originHost) {
                    $shown = Hide-UrlCredential -Text $compare['Origin']
                    if (-not (Get-GitHubReferenceHost -Reference $compare['Origin'] -Named)) {
                        $shown = "$originHost/$shown"
                    }

                    throw "Deploy key $Id is in $shown, but -Repository names ${shownNamed}: give one or the other."
                }
            }

            $target = Format-GitHubTarget -Repository $reference -Item "deploy key $Id"
            if (-not $PSCmdlet.ShouldProcess($target, 'Delete deploy key')) {
                return
            }

            $arguments = @('repo', 'deploy-key', 'delete', $Id)
            Invoke-GitHubCommand -Activity "Deleting deploy key $Id" `
                -Arguments $arguments `
                -Repository $reference | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
