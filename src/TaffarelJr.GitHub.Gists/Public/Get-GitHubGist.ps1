function Get-GitHubGist {
    <#
    .SYNOPSIS
        Returns one gist in full, or lists the authenticated user's
        gists.
    .DESCRIPTION
        gh's own gist list and view have no --json support, so this calls
        GitHub's REST API directly (gists, gists/{id}). A listing fetches
        every page.

        Files is a dictionary keyed by each file's real name, as it is in
        the gist, case and all: 'hello_world.py' stays 'hello_world.py',
        where the other fields are re-cased to PascalCase. Read one file
        with $gist.Files['hello_world.py'], every file object with
        $gist.Files.PSBase.Values, and the names with
        $gist.Files.PSBase.Keys - through PSBase, because a file named
        Keys, Values, or Count would otherwise stand in for the member of
        that name. A file's Content is always its text, even text that
        looks like a date or a number.

        GitHub sends up to a megabyte of each file: a larger one has
        Truncated set and only the start of its Content, and its RawUrl
        has all of it up to ten megabytes. A file larger than that, and a
        gist with more than 300 files - whose own Truncated is set, with
        only the first 300 in Files, and which this warns about - must be
        cloned with Copy-GitHubGist to be read in full.
    .PARAMETER Id
        The gist to describe in full: its id, a URL of it, or a gist
        object, read by its Id, HtmlUrl, or Url.
    .PARAMETER List
        Lists every gist instead of describing one.
    .INPUTS
        System.Object
        The gist to describe, bound to -Id: its id, a URL of it, or a gist
        object, such as one a listing returned.
    .OUTPUTS
        PSCustomObject
        With -List: one object per gist, with the fields GitHub returns -
        Id, Description, Public, Files, and the rest - in PascalCase.
        Without it: one full object, with each file's Content included.
    .EXAMPLE
        $gist = Get-GitHubGist -Id 'https://gist.github.com/me/0123456789abcdef0123456789abcdef'
        $gist.Files.PSBase.Values |
            ForEach-Object { "$($_.Filename): $($_.Size) bytes" }

        Reads a gist by its URL and lists each of its files with its size.
    .EXAMPLE
        Get-GitHubGist -List

        Lists every gist of the authenticated user.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Gists/README.md
    .LINK
        Copy-GitHubGist
    #>
    [CmdletBinding(DefaultParameterSetName = 'View')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'View', ValueFromPipeline)]
        [object]$Id,

        [Parameter(Mandatory, ParameterSetName = 'List')]
        [switch]$List
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            if ($List) {
                $request = @{
                    Endpoint = 'gists?per_page=100'
                    Paginate = $true
                }
                $listed = @(Invoke-GitHubGistApi -Activity 'Listing gists' -Request $request)
                $gists = @(ConvertTo-PascalCaseObject -InputObject $listed -KeepKeysOf 'files')
            }
            else {
                $gistId = ConvertTo-GitHubGistId -Id $Id
                $request = @{
                    Endpoint = "gists/$gistId"
                }
                $gist = Invoke-GitHubGistApi -Activity "Reading gist $gistId" -Request $request
                $gists = @(ConvertTo-PascalCaseObject -InputObject $gist -KeepKeysOf 'files')
            }

            foreach ($gist in $gists) {
                $truncated = $gist.PSObject.Properties['Truncated']
                if ($null -ne $truncated -and $truncated.Value -eq $true) {
                    $shownId = Hide-UrlCredential -Text "$($gist.Id)"
                    $warning = "Gist $shownId has more than 300 files, and GitHub lists only the first 300" +
                    ' in Files: clone it with Copy-GitHubGist for every file.'
                    Write-Warning $warning
                }

                $gist
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
