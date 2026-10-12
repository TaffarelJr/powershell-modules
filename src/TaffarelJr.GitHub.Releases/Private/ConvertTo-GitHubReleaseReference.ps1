using namespace System.Collections

function ConvertTo-GitHubReleaseReference {
    <#
    .SYNOPSIS
        Returns the tag gh takes for a release, and the repository to find
        it in, from a tag or a release object.
    .DESCRIPTION
        An object - one of Get-GitHubRelease's, or a hashtable - is read by
        its TagName, and by its Repository when it has one: Get-GitHubRelease
        attaches the repository a release was read from, so a release piped
        on is acted on there rather than in whichever repository the current
        directory is. A -Repository naming a different repository throws;
        the same repository written another way is the same one, and an
        Enterprise release stays on its own host.

        A list of one tag or release is read as that one, as
        @(Get-GitHubRelease -Tag 'v1') gives; a longer or an empty list
        throws.

        A tag is sent after a --, so whatever it starts with it stays a tag;
        a blank one, $null, or an object with no TagName throws rather than
        reaching gh as nothing, which gh would read as the latest release.

        A parameter that takes both a value and an object by pipeline must
        be an [object]: as a [string], PowerShell turns a piped object into
        its text ("@{TagName=...}") when its TagName is not already text.
    .PARAMETER Release
        A tag, or a release object.
    .PARAMETER Repository
        The caller's -Repository, if it has one.
    .PARAMETER PipelineBound
        Set when the caller's parameter takes pipeline input, so a list is
        answered with advice to pipe it rather than to call once per
        release.
    .OUTPUTS
        An object with Tag and Repository; Repository is $null when neither
        the release nor the caller names one.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Release,

        [AllowNull()]
        [object]$Repository,

        [switch]$PipelineBound
    )

    if ($Release -isnot [string] -and $Release -isnot [IDictionary] -and $Release -is [IEnumerable]) {
        $items = @($Release)
        if ($items.Count -eq 1) {
            $Release = $items[0]
        }
    }

    if ($null -eq $Release) {
        throw 'A release was given, but it is $null: give its tag, or a release from Get-GitHubRelease.'
    }

    if ($Release -is [bool] -or $Release -is [switch]) {
        throw "'$Release' is not a release tag: give the tag's name, such as 'v1.0.0', or a release object."
    }

    if ($Release -isnot [string] -and $Release -isnot [IDictionary] -and $Release -is [IEnumerable]) {
        $advice = if ($PipelineBound) { 'pipe them to name several' } else { 'call once per release' }
        throw "Give one release at a time, not a list of $(@($Release).Count); $advice."
    }

    $tag = $Release
    $origin = $null
    if ($Release -isnot [string] -and $Release -isnot [ValueType]) {
        $values = @{}
        if ($Release -is [IDictionary]) {
            foreach ($key in $Release.PSBase.Keys) {
                $values["$key"] = $Release[$key]
            }
        }
        else {
            foreach ($property in $Release.PSObject.Properties) {
                $values[$property.Name] = $property.Value
            }
        }

        $tag = $values['TagName']
        if ("$tag" -notmatch '\S') {
            throw "A release object needs a TagName, and this one has none: $($Release.GetType().Name)."
        }

        if ($values['Repository']) {
            $origin = ConvertTo-GitHubRepositoryReference -Repository $values['Repository']
        }
    }

    $text = "$tag"
    if ($text -notmatch '\S') {
        throw "'$text' is not a release tag: give the tag's name, such as 'v1.0.0', or a release object."
    }

    $given = ConvertTo-GitHubRepositoryReference -Repository $Repository
    $repositoryReference = $origin
    if ($given -and $origin) {
        $comparison = @{
            Item       = "Release $text"
            Origin     = $origin
            Repository = $given
        }
        $repositoryReference = Assert-GitHubSameRepository @comparison -PassThru
    }
    elseif ($given) {
        $repositoryReference = $given
    }

    return [PSCustomObject]@{
        Tag        = $text
        Repository = $repositoryReference
    }
}
