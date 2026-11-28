#Requires -Version 7.6

<#
.SYNOPSIS
    Pushes the commit in a bundle to the wiki, after checking it is only what
    the generator makes.

.DESCRIPTION
    This is the half of an update that holds the credential that can write, so
    it runs no code from the package. The bundle is data from another job, and
    is not trusted further than it is checked: it must carry exactly one
    commit, on top of the wiki's current tip, made by the GitHub Actions bot,
    and that commit may touch only what Update-ModuleWiki.ps1 writes: Home.md,
    the wiki's _Sidebar.md, a module's folder, and a module's old changelog
    page at the root. Anything else is refused and nothing is pushed.

    The clone is the caller's, checked out with the credential that pushes.
    The script holds none of its own.

.PARAMETER WikiPath
    The clone of the wiki repository, on its branch and with no uncommitted
    change.

.PARAMETER BundlePath
    The bundle Export-WikiChange.ps1 wrote.

.PARAMETER Branch
    The wiki's branch. Defaults to master, the only branch GitHub shows.

.OUTPUTS
    A PSCustomObject with Commit (the commit pushed) and Paths (how many files
    it changed).

.EXAMPLE
    ./build/Send-WikiChange.ps1 -WikiPath ./wiki -BundlePath ./wiki.bundle

    Checks the bundle and pushes its commit to the wiki.
#>
using namespace System.IO

[CmdletBinding()]
[OutputType([PSCustomObject])]
param(
    [Parameter(Mandatory)]
    [string]$WikiPath,

    [Parameter(Mandatory)]
    [string]$BundlePath,

    [string]$Branch = 'master'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path -Path $PSScriptRoot -ChildPath 'ReleaseName.ps1')

$botEmail = '41898282+github-actions[bot]@users.noreply.github.com'

function Test-AllowedPath {
    <#
    .SYNOPSIS
        Says whether a path is one the generator writes.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ($Path -ceq 'Home.md' -or $Path -ceq '_Sidebar.md') {
        return $true
    }

    $root = [regex]::Match($Path, '^(?<name>[^/]+)-Changelog\.md\z')
    if ($root.Success) {
        return Test-ShortModuleName -Name $root.Groups['name'].Value
    }

    $inside = [regex]::Match($Path, '^(?<name>[^/]+)/[A-Za-z0-9_][A-Za-z0-9._-]*\.md\z')
    return $inside.Success -and (Test-ShortModuleName -Name $inside.Groups['name'].Value)
}

$wiki = [Path]::GetFullPath($WikiPath)
$bundle = [Path]::GetFullPath($BundlePath)
if (-not (Test-Path -LiteralPath $bundle -PathType Leaf)) {
    throw "There is no bundle at '$bundle'."
}

$dirty = @(& git -C $wiki status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw "git could not read the wiki clone at '$wiki' (exit $LASTEXITCODE)."
}

if ($dirty.Count -gt 0) {
    throw "The wiki clone at '$wiki' has $($dirty.Count) uncommitted change(s)."
}

& git -C $wiki bundle verify $bundle 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "The bundle at '$bundle' is not a valid bundle for this wiki (exit $LASTEXITCODE)."
}

& git -C $wiki fetch --quiet $bundle HEAD
if ($LASTEXITCODE -ne 0) {
    throw "git could not read the bundle (exit $LASTEXITCODE)."
}

$tip = (& git -C $wiki rev-parse FETCH_HEAD).Trim()
$count = (& git -C $wiki rev-list --count 'HEAD..FETCH_HEAD')
if ([int]$count -ne 1) {
    throw "The bundle carries $count commit(s) beyond the wiki's tip; exactly one is expected."
}

& git -C $wiki merge-base --is-ancestor HEAD $tip
if ($LASTEXITCODE -ne 0) {
    throw "The bundle's commit is not on top of the wiki's current tip, so it is not pushed."
}

$author = (& git -C $wiki log -1 --format=%ae $tip).Trim()
if ($author -cne $botEmail) {
    throw "The bundle's commit is by '$author', not by the GitHub Actions bot."
}

$paths = @(& git -C $wiki diff --name-only --no-renames HEAD $tip)
$refused = @($paths | Where-Object { -not (Test-AllowedPath -Path $_) })
if ($refused.Count -gt 0) {
    throw "The bundle's commit changes $($refused.Count) file(s) the generator does not write: " +
    (($refused | Select-Object -First 3) -join ', ')
}

& git -C $wiki push --quiet origin "${tip}:refs/heads/$Branch"
if ($LASTEXITCODE -ne 0) {
    throw "git could not push the wiki (exit $LASTEXITCODE)."
}

return [PSCustomObject]@{
    Commit = $tip
    Paths  = $paths.Count
}
