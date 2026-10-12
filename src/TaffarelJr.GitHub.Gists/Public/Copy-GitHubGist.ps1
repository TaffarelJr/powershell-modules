function Copy-GitHubGist {
    <#
    .SYNOPSIS
        Clones a gist locally and returns the folder it was cloned into.
    .DESCRIPTION
        Runs gh gist clone, so the folder is a git repository holding every
        file of the gist, and returns the folder, one per gist piped in.
        This is how to read a gist that Get-GitHubGist cannot show whole:
        one with a file over a megabyte, or more than 300 files.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Id
        The gist to clone: its id, a URL of it, or a gist object, read by
        its Id, HtmlUrl, or Url.
    .PARAMETER Destination
        The folder to clone into, relative to PowerShell's location. It is
        for one gist: git clones only into a folder that is new or empty,
        so a second gist piped in with the same -Destination fails. Without
        it, each gist goes into a folder named for its id, under
        PowerShell's location, which must then be a folder.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object
        The gist to clone, bound to -Id: its id, a URL of it, or a gist
        object, such as one Get-GitHubGist returned.
    .OUTPUTS
        System.IO.DirectoryInfo
        The cloned folder, one per gist.
    .EXAMPLE
        $id = '0123456789abcdef0123456789abcdef'
        Copy-GitHubGist -Id $id -Destination ./notes

        Clones the gist into the folder ./notes.
    .EXAMPLE
        Get-GitHubGist -List | Copy-GitHubGist

        Clones every gist of the authenticated user, each into a folder
        named for its id.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Gists/README.md
    .LINK
        Get-GitHubGist
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.DirectoryInfo])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$Id,

        [Parameter(Position = 1)]
        [ValidatePattern('\S', ErrorMessage = '-Destination is blank: give a folder, or leave it out.')]
        [string]$Destination
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

            $given = $PSBoundParameters.ContainsKey('Destination')
            $location = Get-Location
            if (-not $given -and $location.Provider.Name -ne 'FileSystem') {
                $shownLocation = Hide-UrlCredential -Text "$location"
                throw "PowerShell's location, $shownLocation, is not a folder, so no gist can be cloned under it:" +
                ' give -Destination, or go to a folder first.'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $gistId = ConvertTo-GitHubGistId -Id $Id
            $target = $gistId
            if ($given) {
                $target = $Destination
            }

            # A full path, so gh never reads a leading dash as an option, and the
            # folder is the one PowerShell's location names.
            $folder = Resolve-GitHubPath -Path $target
            $shownFolder = Hide-UrlCredential -Text $folder
            if (-not $PSCmdlet.ShouldProcess($shownFolder, "Clone gist $gistId")) {
                return
            }

            $arguments = @('gist', 'clone', $gistId, $folder)
            Invoke-GitHubCommand -Activity "Cloning gist $gistId" -Arguments $arguments | Out-Null
            Get-Item -LiteralPath $folder
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
