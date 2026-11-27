#Requires -Version 7.6

<#
.SYNOPSIS
    Publishes a module package to a repository, unless that version is
    already there.

.DESCRIPTION
    A version on the PowerShell Gallery is permanent, and a publish that was
    interrupted is run again, so a version that is already on the repository
    is reported and left alone, not an error. It is looked up first, and a
    server that answers 409 Conflict to the push is taken to mean the same.

    A repository that is a folder needs no key. Any other needs one, read
    from the environment variable named by -ApiKeyVariable and passed to
    Publish-PSResource as a parameter: it is never put in a command line, and
    never written. When it is missing the message names the variable, not a
    value.

    -Uri registers the repository first, as trusted, and removes it again
    afterwards. Without it the repository must already be registered.

.PARAMETER Package
    The .nupkg to publish.

.PARAMETER Repository
    The name of the repository to publish to, such as PSGallery.

.PARAMETER Uri
    The address to register the repository at, for a repository that is not
    registered already.

.PARAMETER ApiKeyVariable
    The environment variable holding the API key. Defaults to
    PUBLISH_API_KEY.

.OUTPUTS
    A PSCustomObject with Id, Version, Repository, Published and Skipped.

.EXAMPLE
    ./build/Publish-ModulePackage.ps1 -Package ./out/package/TaffarelJr.Tally.0.2.0.nupkg -Repository PSGallery

    Publishes the package to the Gallery with the key in PUBLISH_API_KEY.
#>
using namespace System.IO

[CmdletBinding()]
[OutputType([PSCustomObject])]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Package,

    [Parameter(Mandatory)]
    [string]$Repository,

    [string]$Uri,

    [string]$ApiKeyVariable = 'PUBLISH_API_KEY'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-VersionPresent {
    <#
    .SYNOPSIS
        Returns whether a repository already holds a version of a module.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Id,

        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [string]$Repository
    )

    $found = @(Find-PSResource -Name $Id -Version $Version -Repository $Repository `
            -ErrorAction SilentlyContinue)
    return $found.Count -gt 0
}

$full = [Path]::GetFullPath($Package)
if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
    throw "There is no package at '$full'."
}

if ([Path]::GetExtension($full) -cne '.nupkg') {
    throw "'$full' is not a .nupkg file."
}

Import-Module Microsoft.PowerShell.PSResourceGet
$identity = & (Join-Path -Path $PSScriptRoot -ChildPath 'Get-PackageIdentity.ps1') -Path $full
$registered = $false
if ($Uri) {
    Register-PSResourceRepository -Name $Repository -Uri $Uri -Trusted
    $registered = $true
}

try {
    $target = Get-PSResourceRepository -Name $Repository -ErrorAction Stop
    $isFolder = $target.Uri.IsFile
    $result = [PSCustomObject]@{
        Id         = $identity.Id
        Version    = $identity.Version
        Repository = $Repository
        Published  = $false
        Skipped    = $false
    }

    if (Test-VersionPresent -Id $identity.Id -Version $identity.Version -Repository $Repository) {
        $result.Skipped = $true
        return $result
    }

    $key = [Environment]::GetEnvironmentVariable($ApiKeyVariable)
    if (-not $isFolder -and -not $key) {
        throw "Publishing to $Repository needs an API key in the " +
        "$ApiKeyVariable environment variable."
    }

    $arguments = @{ NupkgPath = $full; Repository = $Repository; ErrorAction = 'Stop' }
    if ($key) {
        $arguments.ApiKey = $key
    }

    try {
        Publish-PSResource @arguments
        $result.Published = $true
    }
    catch {
        if ($_.Exception.Message -notmatch '\b409\b') {
            throw
        }

        $result.Skipped = $true
    }

    return $result
}
finally {
    if ($registered) {
        Unregister-PSResourceRepository -Name $Repository -ErrorAction SilentlyContinue
    }
}
