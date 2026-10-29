function Add-GitHubDeployKey {
    <#
    .SYNOPSIS
        Adds a public SSH key to a repository as a deploy key.
    .DESCRIPTION
        GitHub ties a key added this way to the token that added it; if
        that token is later revoked, the key goes with it.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER KeyFile
        The public key file to add. A relative path is taken from the
        current location.
    .PARAMETER Title
        A title for the key. A blank one is refused.
    .PARAMETER AllowWrite
        Lets the key push, not just pull.
    .PARAMETER Repository
        The repository to add it to, in [HOST/]OWNER/REPO form or as a URL,
        or a repository object. Omit it to use the current directory's
        repository.
        A -Repository given as $null throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. The key file is given as a parameter.
    .OUTPUTS
        None.
    .EXAMPLE
        Add-GitHubDeployKey -KeyFile ~/.ssh/deploy.pub -Title 'CI' `
            -Repository 'OWNER/REPO'

        Adds the public key to OWNER/REPO as a read-only deploy key.
    .EXAMPLE
        Add-GitHubDeployKey ~/.ssh/deploy.pub -AllowWrite -WhatIf

        Shows what adding the key to the current directory's repository as
        a key that can push would do, without adding it.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Get-GitHubDeployKey
    .LINK
        Remove-GitHubDeployKey
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$KeyFile,

        [string]$Title,

        [switch]$AllowWrite,

        [object]$Repository
    )

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

        if ($PSBoundParameters.ContainsKey('Title') -and [string]::IsNullOrWhiteSpace($Title)) {
            throw '-Title is blank: give a title for the key, or leave it out.'
        }

        $given = $PSBoundParameters.ContainsKey('Repository')
        $reference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
        $path = Resolve-GitHubInputFile -Path $KeyFile -Name 'KeyFile'
        $arguments = @('repo', 'deploy-key', 'add', $path)
        if ($Title) {
            $arguments += "--title=$Title"
        }

        if ($AllowWrite) {
            $arguments += '--allow-write'
        }

        $target = Format-GitHubTarget -Repository $reference
        $shownKey = Hide-UrlCredential -Text $KeyFile
        if (-not $PSCmdlet.ShouldProcess($target, "Add deploy key from $shownKey")) {
            return
        }

        Invoke-GitHubCommand -Activity "Adding deploy key $shownKey" `
            -Arguments $arguments `
            -Repository $reference | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
        )
    }
}
