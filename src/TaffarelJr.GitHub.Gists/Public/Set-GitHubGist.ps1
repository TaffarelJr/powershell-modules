using namespace System.IO

function Set-GitHubGist {
    <#
    .SYNOPSIS
        Changes a gist's description, or adds, removes or replaces one of
        its files.
    .DESCRIPTION
        One change per call: -Description, -AddFile, -RemoveFile, or
        -FileName with -ReplaceWith. gh gist edit mixes them badly - the
        replacement file becomes the content of an added one, and a
        description alone opens an editor - so they are kept apart, and
        giving two throws. Files are added and replaced from local files,
        which must be UTF-8 text that is not empty or blank, as for
        New-GitHubGist; they are checked before GitHub is called.

        The description goes to GitHub's API instead, because gh gist edit
        has no non-interactive way to set one and ignores an empty value.
        An empty value clears it.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Id
        The gist to change: its id, a URL of it, or a gist object, read by
        its Id, HtmlUrl, or Url.
    .PARAMETER Description
        The new description. An empty string, or $null, clears it.
    .PARAMETER AddFile
        A local file to add to the gist, under its own file name - the name
        the file system has for it, whatever case it was typed in - relative
        to PowerShell's location. The gist is read first, and a name it
        already has is refused - GitHub would replace that file - so
        replace one with -FileName and -ReplaceWith. Names are compared
        with their case. A gist with more than 300 files, whose names
        GitHub does not all list, is refused too.
    .PARAMETER RemoveFile
        The name of a file to remove from the gist. A blank name, or one with a
        /, a \, a line break, or another control character, which no gist file
        has, is refused.
    .PARAMETER FileName
        The gist file to replace, together with -ReplaceWith.
    .PARAMETER ReplaceWith
        A local file whose content replaces -FileName's, relative to
        PowerShell's location.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object
        The gist to change, bound to -Id: its id, a URL of it, or a gist
        object, such as one Get-GitHubGist returned.
    .OUTPUTS
        None.
    .EXAMPLE
        $id = '0123456789abcdef0123456789abcdef'
        Set-GitHubGist -Id $id -Description 'Scratch notes'

        Changes the description of the gist.
    .EXAMPLE
        $id = '0123456789abcdef0123456789abcdef'
        Set-GitHubGist -Id $id -AddFile ./extra.md

        Adds the local file extra.md to the gist.
    .EXAMPLE
        $id = '0123456789abcdef0123456789abcdef'
        Set-GitHubGist -Id $id -FileName notes.txt -ReplaceWith ./notes.txt

        Replaces the content of the gist's file notes.txt with the local file.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Gists/README.md
    .LINK
        Rename-GitHubGistFile
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$Id,

        [AllowEmptyString()]
        [string]$Description,

        [ValidatePattern('\S', ErrorMessage = '-AddFile is blank: give the path of a local file, or leave it out.')]
        [string]$AddFile,

        [ValidatePattern(
            '^(?!\s*\z)[^/\\\p{Cc}\u2028\u2029]+\z',
            ErrorMessage = '-RemoveFile is not a gist file name: it is blank or holds /, \, or a control character.'
        )]
        [string]$RemoveFile,

        [ValidatePattern(
            '\S',
            ErrorMessage = '-FileName is blank: give the name of a file in the gist, or leave it out.'
        )]
        [string]$FileName,

        [ValidatePattern('\S', ErrorMessage = '-ReplaceWith is blank: give the path of a local file, or leave it out.')]
        [string]$ReplaceWith
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

            if ($PSBoundParameters.ContainsKey('FileName') -and -not $PSBoundParameters.ContainsKey('ReplaceWith')) {
                throw '-FileName works only with -ReplaceWith: it names the gist file whose content -ReplaceWith' +
                ' replaces. Give -ReplaceWith too, or leave -FileName off.'
            }

            if ($PSBoundParameters.ContainsKey('ReplaceWith') -and -not $PSBoundParameters.ContainsKey('FileName')) {
                throw '-ReplaceWith works only with -FileName: it replaces the content of the gist file -FileName' +
                ' names. Give -FileName too, or leave -ReplaceWith off.'
            }

            $candidates = @('Description', 'AddFile', 'RemoveFile', 'FileName')
            $changes = $candidates.Where({ $PSBoundParameters.ContainsKey($_) })
            if ($changes.Count -eq 0) {
                throw 'Say what to change - -Description, -AddFile, -RemoveFile, or -FileName with -ReplaceWith.'
            }

            if ($changes.Count -gt 1) {
                throw "-$($changes[0]) and -$($changes[1]) cannot be used together: gh gist edit mixes changes up," +
                ' so one is made per call. Give only one.'
            }

            $change = $changes[0]
            $local = $null
            $shownFile = $null
            if ($change -eq 'AddFile') {
                $shownFile = Hide-UrlCredential -Text $AddFile
                $typed = Resolve-GitHubInputFile -Path $AddFile -Name 'AddFile'
                $local = Get-GitHubGistLocalFile -Path $typed -Source "-AddFile '$shownFile'"
                Read-GitHubGistFile -Path $local -Source "-AddFile '$shownFile'" | Out-Null
            }
            elseif ($change -eq 'FileName') {
                $shownFile = Hide-UrlCredential -Text $ReplaceWith
                $local = Resolve-GitHubInputFile -Path $ReplaceWith -Name 'ReplaceWith'
                Read-GitHubGistFile -Path $local -Source "-ReplaceWith '$shownFile'" | Out-Null
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
            $target = "gist $gistId"
            if ($change -eq 'Description') {
                if (-not $PSCmdlet.ShouldProcess($target, 'Edit description')) {
                    return
                }

                $request = @{
                    Endpoint = "gists/$gistId"
                    Method   = 'PATCH'
                    RawField = @{ description = $Description }
                    Silent   = $true
                    Confirm  = $false
                    WhatIf   = $false
                }
                Invoke-GitHubGistApi -Activity "Setting the description of gist $gistId" -Request $request
                return
            }

            if ($change -eq 'AddFile') {
                $name = [Path]::GetFileName($local)
                $shownName = Hide-UrlCredential -Text $name
                $request = @{
                    Endpoint = "gists/$gistId"
                }
                $answer = Invoke-GitHubGistApi -Activity "Reading gist $gistId" -Request $request
                $gist = ConvertTo-PascalCaseObject -InputObject $answer -KeepKeysOf 'files'
                $truncated = $gist.PSObject.Properties['Truncated']
                if ($null -ne $truncated -and $truncated.Value -eq $true) {
                    throw "Gist $gistId has more than 300 files, and GitHub lists only the first 300, so whether it" +
                    " already has a file named '$shownName' cannot be told: clone it with Copy-GitHubGist and add the" +
                    ' file there.'
                }

                if ($gist.Files.Contains($name)) {
                    throw "Gist $gistId already has a file named '$shownName', which -AddFile would silently replace;" +
                    " to replace it, give -FileName '$shownName' -ReplaceWith '$shownFile'."
                }
            }

            $edit = switch ($change) {
                'AddFile' { @('--add', $local, $gistId) }
                'RemoveFile' { @("--remove=$RemoveFile", $gistId) }
                'FileName' { @("--filename=$FileName", $gistId, $local) }
            }

            $action = switch ($change) {
                'AddFile' { "Add file $shownName" }
                'RemoveFile' { "Remove file $(Hide-UrlCredential -Text $RemoveFile)" }
                'FileName' { "Replace file $(Hide-UrlCredential -Text $FileName)" }
            }

            if (-not $PSCmdlet.ShouldProcess($target, $action)) {
                return
            }

            $arguments = @('gist', 'edit') + $edit
            Invoke-GitHubCommand -Activity "Editing gist $gistId" -Arguments $arguments | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
