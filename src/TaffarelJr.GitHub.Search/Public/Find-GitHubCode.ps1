function Find-GitHubCode {
    <#
    .SYNOPSIS
        Searches GitHub for code.
    .DESCRIPTION
        Give a query, a filter, or both: with neither the search would
        cover all of GitHub, so that throws. A filter that is passed but
        empty or blank throws for the same reason, rather than being left
        out. A list value holding a comma throws too, as gh would split it
        into two filters: give each value on its own, and put a
        qualifier whose one value holds a comma in -Query, quoted
        (label:"a,b").
    .PARAMETER Query
        Search keywords, each one a separate value, or none to rely on the
        filters alone. A value with a space in it is searched as an exact
        phrase, so 'react lint' is one phrase where 'react', 'lint' is two
        keywords. A qualifier such as language:go is a value of its own,
        and one starting with a dash excludes (-language:go).
    .PARAMETER Owner
        Only code owned by one of these users or organizations.
    .PARAMETER Repository
        Only code in one of these repositories, each as OWNER/REPO,
        a URL, HOST/OWNER/REPO, or a repository object such as another
        search result's Repository; gh is given its OWNER/REPO. gh
        searches its default host - the one GH_HOST names, else the one
        host gh is logged in to, else github.com. A named host is
        compared with GH_HOST when it is set and with github.com when it
        is not, and another host throws; someone logged in only to an
        Enterprise host sets GH_HOST.
    .PARAMETER Language
        Only files in this language.
    .PARAMETER Filename
        Only files with this name.
    .PARAMETER Extension
        Only files with this extension.
    .PARAMETER Match
        Restricts the search to file contents or file paths: file or
        path.
    .PARAMETER Size
        A size range in kilobytes.
    .PARAMETER Limit
        The most results to fetch, from 1 to 1000. gh's default is 30.
        GitHub returns at most 1000 results for any search.
    .INPUTS
        None
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object per match - Path, Sha, Url, Repository, TextMatches.
    .EXAMPLE
        Find-GitHubCode -Query 'Invoke-GitHubCommand', '-path:test' `
            -Owner 'TaffarelJr' -Extension 'ps1'

        Finds PowerShell files in TaffarelJr's repositories that mention
        Invoke-GitHubCommand, except those under a test path.
    .EXAMPLE
        Find-GitHubCode -Repository 'cli/cli' -Filename 'shared.go'

        Finds every file named shared.go in cli/cli, with no keywords at
        all.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Search/README.md
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Position = 0)]
        [string[]]$Query,

        [string[]]$Owner,

        [object[]]$Repository,

        [string]$Language,

        [string]$Filename,

        [string]$Extension,

        [ValidateSet('file', 'path')]
        [string[]]$Match,

        [string]$Size,

        [ValidateRange(1, 1000)]
        [int]$Limit
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $flags = [ordered]@{
            Owner      = '--owner'
            Repository = '--repo'
            Language   = '--language'
            Filename   = '--filename'
            Extension  = '--extension'
            Match      = '--match'
            Size       = '--size'
            Limit      = '--limit'
        }

        $search = @{
            Subcommand = 'code'
            JsonFields = 'path,repository,sha,textMatches,url'
            Command    = $MyInvocation.MyCommand
            Bound      = $PSBoundParameters
            Flag       = $flags
            Query      = $Query
        }
        $arguments = ConvertTo-GitHubSearchArgument @search

        $out = Invoke-GitHubCommand -Activity 'Searching code' -Argument $arguments
        return ConvertFrom-GitHubJson -Line $out
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
