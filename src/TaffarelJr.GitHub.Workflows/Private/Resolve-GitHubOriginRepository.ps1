using namespace System.Collections

function Resolve-GitHubOriginRepository {
    <#
    .SYNOPSIS
        Returns the repository to act in for a piped object: the one
        -Repository names, else the one the object came from.
    .DESCRIPTION
        An object is acted on where it came from: its Repository property
        (which Get-GitHubWorkflowRun, Get-GitHubWorkflow, and
        Get-GitHubCache attach), else the repository in its Url. An object
        of unknown origin, or a plain id, acts on the current directory's
        repository.

        A -Repository that names a different repository from the
        object's throws: gh would act in the -Repository one, on an item
        the caller found somewhere else. Core's Assert-GitHubSameRepository
        compares them, so the same repository written another way - with
        or without its host, in another case, or as a clone URL - agrees.
    .PARAMETER Repository
        The repository given, as text or a repository object; $null when
        none was.
    .PARAMETER InputObject
        The piped object, read for its Repository property or key. A
        collection of one is read as its element, as the converters do.
    .PARAMETER Url
        A run's web address, read for its repository when the object
        carries none.
    .PARAMETER Item
        What the object is, for the message - such as 'Workflow run 5'.
    .OUTPUTS
        The repository reference; nothing when none is known.
    .EXAMPLE
        $repository = Resolve-GitHubOriginRepository -Repository $Repository `
            -InputObject $cache -Item 'Cache 7'

        Gives 'o/r' for a cache Get-GitHubCache -Repository 'o/r' listed,
        and throws if -Repository named another repository.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object]$Repository,

        [AllowNull()]
        [object]$InputObject,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$Item
    )

    $given = ConvertTo-GitHubRepositoryReference -Repository $Repository
    $origin = $null
    $isList = $InputObject -isnot [string] -and $InputObject -isnot [IDictionary] -and $InputObject -is [IEnumerable]
    if ($isList -and @($InputObject).Count -eq 1) {
        $InputObject = @($InputObject)[0]
    }

    if ($null -ne $InputObject -and $InputObject -isnot [string] -and $InputObject -isnot [ValueType]) {
        $value = $null
        if ($InputObject -is [IDictionary]) {
            foreach ($key in $InputObject.PSBase.Keys) {
                if ("$key" -eq 'Repository') {
                    $value = $InputObject[$key]
                }
            }
        }
        else {
            $value = $InputObject.PSObject.Properties['Repository']?.Value
        }

        if ($value) {
            $origin = ConvertTo-GitHubRepositoryReference -Repository $value
        }
    }

    if (-not $origin -and $Url -match '^(?<repository>https?://[^/\s]+/[^/\s]+/[^/\s]+)/actions/') {
        $origin = ConvertTo-GitHubRepositoryReference -Repository $Matches['repository']
    }

    if ($given -and $origin) {
        return Assert-GitHubSameRepository -Item $Item -Origin $origin -Repository $given -PassThru
    }

    if ($given) {
        return $given
    }

    if ($origin) {
        return $origin
    }
}
