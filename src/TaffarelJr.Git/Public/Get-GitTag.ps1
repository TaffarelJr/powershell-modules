using namespace System.Management.Automation

function Get-GitTag {
    <#
    .SYNOPSIS
        Returns tag names, optionally filtered and version-sorted.
    .DESCRIPTION
        One name per tag, sorted by name byte by byte (so uppercase before
        lowercase: 'Zed' before 'alpha'), whatever the user's config says:
        column.ui and tag.sort, which would otherwise lay the names out in
        columns or reorder them, are overridden.
    .PARAMETER Pattern
        A glob pattern, such as 'v*', to filter tag names by, matched as
        'git tag --list' matches it: '*' also matches a '/', so 're*'
        matches 'release/1.0', and a name with no wildcard matches only the
        tag of exactly that name. Omit it to list every tag.
    .PARAMETER SortByVersion
        Sorts the result newest-first by semantic version, skipping any
        tag name that is not a valid version, instead of the default
        byte-by-byte name order. Drops one leading lowercase 'v' before
        parsing, so 'v1.2.3' sorts correctly too, while 'vv1.2.3' and
        'V1.2.3' are not versions.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.String
        The name of each tag.
    .EXAMPLE
        Get-GitTag -Pattern 'v*' -SortByVersion

        Lists the version tags, newest version first.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        New-GitTag
    .LINK
        Remove-GitTag
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Pattern,

        [switch]$SortByVersion,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $arguments = @('tag', '--list', '--no-column', '--sort=refname')
        if ($Pattern) {
            $arguments += $Pattern
        }

        $tags = Invoke-GitCommand -Activity 'Listing tags' -Arguments $arguments -RepoPath $RepoPath
        if (-not $SortByVersion) {
            return $tags
        }

        $parsed = foreach ($tag in $tags) {
            $version = $null
            if ([SemanticVersion]::TryParse(($tag -creplace '^v', ''), [ref]$version)) {
                [PSCustomObject]@{
                    Tag     = $tag
                    Version = $version
                }
            }
        }

        return $parsed | Sort-Object -Property Version -Descending | Select-Object -ExpandProperty Tag
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
