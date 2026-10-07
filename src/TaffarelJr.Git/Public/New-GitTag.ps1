function New-GitTag {
    <#
    .SYNOPSIS
        Creates a tag.
    .DESCRIPTION
        Tags -Ref, or HEAD: a lightweight tag, or an annotated one when
        -Message is given. A name git would refuse, or one a tag already
        has, throws before anything is made, and the tag stays local until
        it is pushed.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The tag name.
    .PARAMETER Ref
        The commit to tag. Defaults to HEAD.
    .PARAMETER Message
        Creates an annotated tag with this message, instead of a
        lightweight one. An empty message, given, still makes an annotated
        tag.
    .PARAMETER RepoPath
        The repo to tag. Omit it to use the current working directory.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        New-GitTag -Name 'v1.2.0'

        Creates a lightweight tag at HEAD.
    .EXAMPLE
        New-GitTag -Name 'v1.2.0' -Ref 'main' -Message 'Release 1.2.0'

        Creates an annotated tag with a message at the tip of main.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitTag
    .LINK
        Remove-GitTag
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Name,

        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Ref,

        [string]$Message,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
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

        $annotated = $PSBoundParameters.ContainsKey('Message')
        $arguments = @('tag')
        if ($annotated) {
            $arguments += @('-a', '-m', $Message)
        }

        $arguments += $Name
        if ($Ref) {
            $arguments += $Ref
        }

        $activity = "Creating tag $Name"
        $root = Get-GitRepoLocation -Activity $activity -RepoPath $RepoPath -AllowBare
        Assert-GitNameAvailable -Kind 'tag' -Name $Name -Activity $activity -RepoPath $RepoPath
        $at = if ($Ref) { $Ref } else { 'HEAD' }
        Assert-GitRevision -Revision $at -Activity $activity -AnyObject -RepoPath $RepoPath
        $action = if ($annotated) { 'Create annotated tag' } else { 'Create tag' }
        if ($Ref) {
            $action += ", at $Ref"
        }

        if (-not $PSCmdlet.ShouldProcess("$root tag $Name", $action)) {
            return
        }

        Invoke-GitCommand -Activity $activity -Arguments $arguments -RepoPath $RepoPath | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
