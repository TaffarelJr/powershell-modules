using namespace System.Collections.Generic
using namespace System.Collections.Specialized
using namespace System.IO

function New-GitHubGist {
    <#
    .SYNOPSIS
        Creates a gist from one or more local files, or from content
        given directly.
    .DESCRIPTION
        The gist is created through GitHub's API (POST gists) with the
        request built here, so each file's content reaches GitHub exactly:
        no newline added, no line ending changed, and a UTF-8 byte-order
        mark at the start of a file dropped, so a script saved with one
        by Windows PowerShell still starts with its #! line. Like
        gh gist create, it makes a secret gist unless told -Public, with
        an empty description unless given one.

        The gist's source is always named: files with -Path, or text with
        -Content and -FileName - never both. A file must be UTF-8 text
        that is not empty or blank; anything else is refused before GitHub
        is called.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Path
        The local files to include, relative to PowerShell's location, each
        kept under its own file name - the name the file system has for it,
        whatever case it was typed in. A wildcard (*.md) is expanded here to
        the files it matches, hidden ones aside; escape a * ? [ or ] that is
        part of a name with a backtick ('a`[1`].txt'). One file named twice,
        or two files with the same name - after the wildcards are expanded -
        are refused, as a gist holds one file per name; names that differ
        only in case are different names.
    .PARAMETER Content
        Content to use as the gist's one file, instead of -Path. It must
        not be empty or blank.
    .PARAMETER FileName
        The file name to give -Content. It must not be blank or hold a /, a
        \, a line break, or another control character, which GitHub refuses
        in a gist file name.
    .PARAMETER Description
        A description for the gist.
    .PARAMETER Public
        Makes the gist public instead of secret.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None.
    .OUTPUTS
        System.String
        The new gist's URL.
    .EXAMPLE
        New-GitHubGist -Path 'docs/*.md' -Description 'Notes'

        Creates a secret gist holding every Markdown file in the docs
        folder.
    .EXAMPLE
        New-GitHubGist -Content 'Hello, world.' -FileName hello.txt -Public

        Creates a public gist with one file, hello.txt, and returns its URL.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Gists/README.md
    .LINK
        Get-GitHubGist
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Path,

        [AllowEmptyString()]
        [string]$Content,

        [ValidatePattern(
            '^(?!\s*\z)[^/\\\p{Cc}\u2028\u2029]+\z',
            ErrorMessage = '-FileName is not a gist file name: it is blank or holds /, \, or a control character.'
        )]
        [string]$FileName,

        [string]$Description,

        [switch]$Public
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

        $givenPath =$PSBoundParameters.ContainsKey('Path')
        $givenContent = $PSBoundParameters.ContainsKey('Content')
        $givenName = $PSBoundParameters.ContainsKey('FileName')
        if ($givenPath -and $givenContent) {
            throw '-Path and -Content cannot be used together: a gist is made from files or from content.' +
            ' Give only one.'
        }

        if ($givenPath -and $givenName) {
            throw '-Path and -FileName cannot be used together: each -Path file keeps its own name. Give only one.'
        }

        if ($givenContent -and -not $givenName) {
            throw '-Content works only with -FileName: its file needs a name in the gist.' +
            ' Give -FileName too, or leave -Content off.'
        }

        if ($givenName -and -not $givenContent) {
            throw '-FileName works only with -Content: it names the file -Content becomes.' +
            ' Give -Content too, or leave -FileName off.'
        }

        if (-not $givenPath -and -not $givenContent) {
            throw 'Say what the gist is to hold - -Path, or -Content with -FileName.'
        }

        # Ordinal, so names that differ only in case stay two files.
        $files = [OrderedDictionary]::new([StringComparer]::Ordinal)
        if ($givenContent) {
            Assert-GitHubGistText -Text $Content -Source '-Content'
            $files[$FileName] = @{ content = [string]$Content }
        }
        else {
            $sources = foreach ($value in $Path) {
                Resolve-GitHubGistSource -Path $value
            }

            $seen = [HashSet[string]]::new([StringComparer]::Ordinal)
            foreach ($source in $sources) {
                if (-not $seen.Add($source.Path)) {
                    $shownPath = Hide-UrlCredential -Text $source.Path
                    throw "-Path names the file '$shownPath' more than once: give each file once."
                }

                $name = [Path]::GetFileName($source.Path)
                if ($files.Contains($name)) {
                    $shownName = Hide-UrlCredential -Text $name
                    throw "More than one of the -Path files is named '$shownName', and a gist holds one file per name."
                }

                $files[$name] = @{ content = Read-GitHubGistFile -Path $source.Path -Source $source.Source }
            }
        }

        $shownNames = @($files.PSBase.Keys | Hide-UrlCredential)
        $target = $shownNames -join ', '
        $visibility = if ($Public) { 'public' } else { 'secret' }
        if (-not $PSCmdlet.ShouldProcess($target, "Create $visibility gist")) {
            return
        }

        $gist = [ordered]@{
            description = "$Description"
            files       = $files
            public      = [bool]$Public
        }
        $request = @{
            Endpoint = 'gists'
            Method   = 'POST'
            Body     = ConvertTo-Json -InputObject $gist -Depth 4 -Compress
            Confirm  = $false
            WhatIf   = $false
        }
        $response = Invoke-GitHubGistApi -Activity 'Creating the gist' -Request $request

        $url = $null
        if ($null -ne $response -and $null -ne $response.PSObject.Properties['html_url']) {
            $url = $response.html_url
        }

        if (-not $url) {
            throw "Creating the gist succeeded, but GitHub's answer has no html_url to return:" +
            ' look for the new gist with Get-GitHubGist -List.'
        }

        return $url
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
        )
    }
}
