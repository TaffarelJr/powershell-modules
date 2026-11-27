#Requires -Version 7.6

<#
.SYNOPSIS
    Works out the next version of one module from the commits that touch it,
    or checks one that was asked for.

.DESCRIPTION
    A module's releases are the tags "<ModuleName>/vX.Y.Z". The last release
    is the highest such tag reachable from HEAD. The commits since it that
    touch src/<ModuleName> decide the next version:

      - no commits that count: there is nothing to release;
      - a feature, or a breaking change: the minor number goes up. Below 1.0.0
        a breaking change is a minor bump too, so the module stays on 0.x until
        the owner decides it is ready for 1.0.0;
      - anything else that counts (a fix, a refactor, a performance change):
        the patch number goes up.

    Documentation, test, chore, build and style commits do not count. A module
    with no release yet gets 0.1.0. Only the commits under the module's own
    folder are read, so a change to another module never moves it.

    git-cliff reads the commits, with the same rules as the release notes
    (.github/cliff.toml). Its own --bumped-version is not used: it counts the
    commits of every module, so an untouched module is given a new version
    when another one changes.

    -Version names the version to release instead. It must be three numbers,
    higher than the last release, and not already a tag anywhere in the
    repository. It is taken whatever the commits say, so a release made of
    documentation changes alone is possible.

.PARAMETER Module
    The module's folder name under src/, such as TaffarelJr.Tally.

.PARAMETER Version
    The version to release, MAJOR.MINOR.PATCH.

.PARAMETER RepositoryPath
    The repository to read. Defaults to the one holding this script.

.PARAMETER Cliff
    The git-cliff executable. Defaults to the one on the path.

.PARAMETER Config
    The git-cliff configuration. Defaults to .github/cliff.toml in the
    repository.

.OUTPUTS
    A PSCustomObject with Module, Last (the last released version, or $null),
    Next (the version to release, or $null when there is nothing to release),
    Tag (the tag that version will have, or $null), Reason ('first release',
    'minor', 'patch', 'chosen' or 'nothing releasable') and Commits (how many
    commits count).

.EXAMPLE
    ./build/Get-NextVersion.ps1 -Module TaffarelJr.Tally

    Returns the version the next release of the Tally module would have.

.EXAMPLE
    ./build/Get-NextVersion.ps1 -Module TaffarelJr.Tally -Version 1.0.0

    Checks that 1.0.0 is a valid next version for the Tally module.
#>
using namespace System.IO

[CmdletBinding()]
[OutputType([PSCustomObject])]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Module,

    [string]$Version,

    [string]$RepositoryPath = (Join-Path -Path $PSScriptRoot -ChildPath '..'),

    [string]$Cliff = 'git-cliff',

    [string]$Config
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Version {
    <#
    .SYNOPSIS
        Refuses a version that is not three numbers.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Version
    )

    if ($Version -notmatch '^\d+\.\d+\.\d+$') {
        throw "Version '$Version' is not MAJOR.MINOR.PATCH, three numbers such as 0.2.0."
    }
}

function Get-LastVersion {
    <#
    .SYNOPSIS
        Returns the highest released version of a module reachable from HEAD,
        or nothing when there is none.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Repository,

        [Parameter(Mandatory)]
        [string]$Module
    )

    $prefix = "$Module/v"
    $tags = @(& git -C $Repository tag --list "$prefix*" --merged HEAD)
    $versions = @($tags |
            ForEach-Object { $_.Substring($prefix.Length) } |
            Where-Object { $_ -match '^\d+\.\d+\.\d+$' })
    if ($versions.Count -eq 0) {
        return
    }

    $versions | Sort-Object { [version]$_ } | Select-Object -Last 1
}

function Get-ModuleCommit {
    <#
    .SYNOPSIS
        Returns the commits since the module's last release that touch its
        folder and count towards a version: git-cliff's, with the rules in
        its configuration.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Repository,

        [Parameter(Mandatory)]
        [string]$Module,

        [Parameter(Mandatory)]
        [string]$Cliff,

        [Parameter(Mandatory)]
        [string]$Config
    )

    $pattern = '^' + [regex]::Escape($Module) + '/v[0-9].*'
    $json = & $Cliff --config $Config --repository $Repository `
        --include-path "src/$Module/**" --tag-pattern $pattern `
        --unreleased --context 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "git-cliff failed for '$Module' (exit $LASTEXITCODE)."
    }

    $releases = @(($json -join "`n") | ConvertFrom-Json)
    @($releases | Where-Object { -not $_.version } | ForEach-Object { $_.commits })
}

function Get-ChangeKind {
    <#
    .SYNOPSIS
        Returns 'major', 'minor' or 'patch' for the commits, given the last
        version: a breaking change is major from 1.0.0 on and minor below it;
        a feature is minor; anything else is a patch.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Last,

        [Parameter(Mandatory)]
        [object[]]$Commit
    )

    $breaking = @($Commit | Where-Object { $_.breaking }).Count -gt 0
    if ($breaking -and [version]$Last -ge [version]'1.0.0') {
        return 'major'
    }

    $feature = @($Commit | Where-Object { $_.group -eq 'Added' }).Count -gt 0
    if ($breaking -or $feature) {
        return 'minor'
    }

    return 'patch'
}

function Step-Version {
    <#
    .SYNOPSIS
        Returns the version after $Last for a major, minor or patch change.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Last,

        [Parameter(Mandatory)]
        [ValidateSet('major', 'minor', 'patch')]
        [string]$Kind
    )

    $v = [version]$Last
    switch ($Kind) {
        'major' { return '{0}.0.0' -f ($v.Major + 1) }
        'minor' { return '{0}.{1}.0' -f $v.Major, ($v.Minor + 1) }
        default { return '{0}.{1}.{2}' -f $v.Major, $v.Minor, ($v.Build + 1) }
    }
}

function Assert-NewTag {
    <#
    .SYNOPSIS
        Refuses a version whose tag already exists anywhere in the repository,
        including on a branch HEAD does not contain.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Repository,

        [Parameter(Mandatory)]
        [string]$Module,

        [Parameter(Mandatory)]
        [string]$Version
    )

    $existing = @(& git -C $Repository tag --list "$Module/v$Version")
    if ($existing.Count -gt 0) {
        throw "$Module/v$Version already exists as a tag."
    }
}

function Get-Result {
    <#
    .SYNOPSIS
        Returns the result object.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Module,

        [string]$Last,

        [string]$Next,

        [Parameter(Mandatory)]
        [string]$Reason,

        [Parameter(Mandatory)]
        [int]$Commits
    )

    return [PSCustomObject]@{
        Module  = $Module
        Last    = $Last ? $Last : $null
        Next    = $Next ? $Next : $null
        Tag     = $Next ? "$Module/v$Next" : $null
        Reason  = $Reason
        Commits = $Commits
    }
}

$repository = [Path]::GetFullPath($RepositoryPath)
if (-not $Config) {
    $Config = Join-Path -Path $repository -ChildPath '.github' -AdditionalChildPath 'cliff.toml'
}

if (-not (Test-Path -LiteralPath $Config -PathType Leaf)) {
    throw "There is no git-cliff configuration at '$Config'; without one git-cliff " +
    'silently applies its own default rules.'
}

$moduleFolder = Join-Path -Path $repository -ChildPath 'src' -AdditionalChildPath $Module
if (-not (Test-Path -LiteralPath $moduleFolder -PathType Container)) {
    throw "There is no module folder src/$Module in '$repository'."
}

$last = Get-LastVersion -Repository $repository -Module $Module
$commits = @(Get-ModuleCommit -Repository $repository -Module $Module -Cliff $Cliff -Config $Config)

if ($Version) {
    Assert-Version -Version $Version
    if ($last -and [version]$Version -le [version]$last) {
        throw "Version $Version is not higher than the last release of $Module, $last."
    }

    Assert-NewTag -Repository $repository -Module $Module -Version $Version
    return Get-Result -Module $Module -Last $last -Next $Version -Reason 'chosen' `
        -Commits $commits.Count
}

if ($commits.Count -eq 0) {
    return Get-Result -Module $Module -Last $last -Reason 'nothing releasable' -Commits 0
}

if (-not $last) {
    return Get-Result -Module $Module -Next '0.1.0' -Reason 'first release' `
        -Commits $commits.Count
}

$kind = Get-ChangeKind -Last $last -Commit $commits
$next = Step-Version -Last $last -Kind $kind
Assert-NewTag -Repository $repository -Module $Module -Version $next
return Get-Result -Module $Module -Last $last -Next $next -Reason $kind -Commits $commits.Count
