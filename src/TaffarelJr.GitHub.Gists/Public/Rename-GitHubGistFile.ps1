function Rename-GitHubGistFile {
    <#
    .SYNOPSIS
        Renames a file within a gist.
    .DESCRIPTION
        Runs gh gist rename, which changes the name of one file of the
        gist, keeping its content, and leaves the gist's other files alone.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Id
        The gist: its id, a URL of it, or a gist object, read by its Id,
        HtmlUrl, or Url.
    .PARAMETER OldName
        The file's current name. It must not be blank.
    .PARAMETER NewName
        The file's new name. It must not be blank or hold a /, a \, a line
        break, or another control character, which GitHub refuses in a gist
        file name.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object
        The gist, bound to -Id: its id, a URL of it, or a gist object, such
        as one Get-GitHubGist returned.
    .OUTPUTS
        None.
    .EXAMPLE
        $id = '0123456789abcdef0123456789abcdef'
        Rename-GitHubGistFile -Id $id -OldName notes.txt -NewName README.md

        Renames the file notes.txt of the gist to README.md.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Gists/README.md
    .LINK
        Set-GitHubGist
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$Id,

        [Parameter(Mandatory, Position = 1)]
        [AllowEmptyString()]
        [ValidatePattern('\S', ErrorMessage = '-OldName is blank: give the name of a file in the gist.')]
        [string]$OldName,

        [Parameter(Mandatory, Position = 2)]
        [AllowEmptyString()]
        [ValidatePattern(
            '^(?!\s*\z)[^/\\\p{Cc}\u2028\u2029]+\z',
            ErrorMessage = '-NewName is not a gist file name: it is blank or holds /, \, or a control character.'
        )]
        [string]$NewName
    )

    process {
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

            $gistId = ConvertTo-GitHubGistId -Id $Id
            $shownOld = Hide-UrlCredential -Text $OldName
            $shownNew = Hide-UrlCredential -Text $NewName
            if (-not $PSCmdlet.ShouldProcess("gist $gistId", "Rename file $shownOld to $shownNew")) {
                return
            }

            $arguments = @('gist', 'rename', '--', $gistId, $OldName, $NewName)
            Invoke-GitHubCommand -Activity "Renaming $shownOld in gist $gistId" -Arguments $arguments | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
