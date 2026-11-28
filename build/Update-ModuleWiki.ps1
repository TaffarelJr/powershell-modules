#Requires -Version 7.6

<#
.SYNOPSIS
    Writes a module's pages into a clone of the repository's wiki and commits
    them, when they changed.

.DESCRIPTION
    The pages are made from the module's released package, so they say exactly
    what was published: a page for every exported function, from its help;
    an overview page, from the module's README; the changelog, as the package
    carries it; and a sidebar for the module's folder. Home and the sidebar
    of the wiki's own pages list every module that has a folder in the wiki,
    each with the version of its newest release tag and the description in
    its manifest at that tag, so a run for one module keeps the others. A
    folder in the wiki whose module has no release tag stops every run until
    the folder is removed.

    A wiki page is addressed by its name alone, wherever its file is, so a
    page name is never used twice. A function's page is named for the
    function; the others are <Name> and <Name>-Changelog. Everything is
    checked and every page is made before the wiki is changed. These are
    refused: a page that would take a name the wiki already uses or one the
    generator keeps for itself (Home, and any name that starts with an
    underscore); a function whose name could not be a page name; a module that
    exports nothing; a function whose help lacks what its page needs; a README
    that links to a file or a folder; a package that is not a published
    release; and a package older than the module's newest release.

    The module's folder is rewritten whole: a function that is gone loses its
    page, and a hand edit there is overwritten. The module's own changelog
    page at the wiki's root, where earlier releases put it, is removed.
    Home.md and the wiki's own _Sidebar.md are rewritten too, whatever they
    held, and nothing else in the wiki is touched.

    The wiki is a separate git repository. This works in a clone of it that
    the caller made and will push, so the script itself holds no credential.
    Everything in the clone is committed, so a clone with an uncommitted change
    is refused. A change is a new commit, never an amend, made as the GitHub
    Actions bot. Pages that did not change make no commit.

.PARAMETER Package
    The module's released .nupkg.

.PARAMETER WikiPath
    A clone of the wiki repository.

.PARAMETER RepositoryPath
    The repository holding the release tags. Defaults to the one holding this
    script.

.PARAMETER SourceRoot
    The folder holding the modules' source, put on PSModulePath so a module
    that the documented one requires resolves. Defaults to src/ in the
    repository.

.OUTPUTS
    A PSCustomObject with Module (the short name), Version, Pages (how many
    command pages the folder holds) and Changed (whether a commit was made).

.EXAMPLE
    ./build/Update-ModuleWiki.ps1 ./out/package/TaffarelJr.Tally.0.2.0.nupkg -WikiPath ./wiki

    Rewrites the Tally pages in ./wiki and commits them if they changed.
#>
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.IO.Compression
using namespace System.Text

[CmdletBinding()]
[OutputType([PSCustomObject])]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Package,

    [Parameter(Mandatory)]
    [string]$WikiPath,

    [string]$RepositoryPath = (Join-Path -Path $PSScriptRoot -ChildPath '..'),

    [string]$SourceRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path -Path $PSScriptRoot -ChildPath 'ReleaseName.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'WikiText.ps1')

function Expand-Package {
    <#
    .SYNOPSIS
        Extracts the files of a package, not its packaging, into a folder.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Package,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    $root = [Path]::GetFullPath($Destination)
    $null = New-Item -ItemType Directory -Path $root -Force
    $zip = [ZipFile]::OpenRead($Package)
    try {
        foreach ($entry in $zip.Entries) {
            $skip = $entry.FullName -match '^(_rels/|package/|\[Content_Types\])'
            if ($skip -or $entry.FullName.EndsWith('/', [StringComparison]::Ordinal)) {
                continue
            }

            $target = [Path]::GetFullPath((Join-Path -Path $root -ChildPath $entry.FullName))
            $what = "The package holds '$($entry.FullName)'"
            Assert-InsideFolder -Folder $root -Path $target -Description $what
            $null = New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force
            [ZipFileExtensions]::ExtractToFile($entry, $target, $true)
        }
    }
    finally {
        $zip.Dispose()
    }
}

function Assert-InsideFolder {
    <#
    .SYNOPSIS
        Refuses a full path that is not inside a folder.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Folder,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Description
    )

    $prefix = [Path]::GetFullPath($Folder).TrimEnd([Path]::DirectorySeparatorChar) +
    [Path]::DirectorySeparatorChar
    if (-not $Path.StartsWith($prefix, [StringComparison]::Ordinal)) {
        throw "$Description, which is outside its own folder."
    }
}

function Get-ModuleHelpData {
    <#
    .SYNOPSIS
        Returns the help of every function a module exports, read in a
        process of its own so the import is not kept.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Manifest,

        [Parameter(Mandatory)]
        [string]$SourceRoot,

        [Parameter(Mandatory)]
        [string]$Work
    )

    $json = Join-Path -Path $Work -ChildPath 'help.json'
    $script = Join-Path -Path $PSScriptRoot -ChildPath 'Get-ModuleHelp.ps1'
    $arguments = @('-Manifest', $Manifest, '-OutputPath', $json, '-SourceRoot', $SourceRoot)
    $output = & pwsh -NoProfile -File $script @arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "A fresh process could not read the help of the module (exit $LASTEXITCODE): " +
        ($output -join ' ')
    }

    $text = [File]::ReadAllText($json, [UTF8Encoding]::new($false, $true))
    return @($text | ConvertFrom-Json)
}

function Get-HelpProblem {
    <#
    .SYNOPSIS
        Returns what a command's help lacks that its page needs: a synopsis, a
        description, an example, and a description of every parameter.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Help
    )

    $first = @($Help.Syntax)[0]
    if (-not $Help.Synopsis -or $Help.Synopsis -ceq $first) {
        'has no synopsis'
    }

    if (-not $Help.Description) {
        'has no description'
    }

    if (@($Help.Examples).Count -eq 0) {
        'has no example'
    }

    foreach ($parameter in @($Help.Parameters)) {
        if (-not $parameter.Description) {
            "has no description of -$($parameter.Name)"
        }
    }
}

function Assert-HelpComplete {
    <#
    .SYNOPSIS
        Refuses a module that exports nothing, or whose help lacks what the
        pages need, naming each function.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Module,

        [AllowEmptyCollection()]
        [PSCustomObject[]]$Help
    )

    if (@($Help).Count -eq 0) {
        throw "$Module exports no function, so it has no pages."
    }

    $problems = foreach ($item in $Help) {
        Get-HelpProblem -Help $item | ForEach-Object { "$($item.Name) $_" }
    }

    if (@($problems).Count -gt 0) {
        throw "The help of $Module cannot be made into pages: $(@($problems) -join '; ')."
    }
}

function Get-ReleaseVersion {
    <#
    .SYNOPSIS
        Returns a module's released versions, newest first. Every release tag
        counts, whether or not it is reachable from the checked-out commit.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Repository,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $tags = @(& git -C $Repository tag --list (Get-ReleaseTagGlob -Module $Name))
    if ($LASTEXITCODE -ne 0) {
        throw "git could not list the release tags of $Name (exit $LASTEXITCODE)."
    }

    $parsed = @($tags | ForEach-Object { ConvertFrom-ReleaseTag -Tag $_ })
    $versions = @($parsed | Where-Object { $_ -and $_.Name -ceq $Name } | ForEach-Object Version)
    return @($versions | Sort-Object { [version]$_ } -Descending)
}

function Assert-NewestRelease {
    <#
    .SYNOPSIS
        Refuses a version that is not a release tag of the module, or that has
        a newer release, which its pages would roll back.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Repository,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Version
    )

    $released = @(Get-ReleaseVersion -Repository $Repository -Name $Name)
    if ($Version -cnotin $released) {
        throw "$Name $Version has no release tag, so it is not a published release " +
        'and its pages are not written.'
    }

    $newer = @($released | Where-Object { [version]$_ -gt [version]$Version })
    if ($newer.Count -gt 0) {
        throw "$Name $Version is not the newest release: $($newer[0]) is, " +
        'and its pages would be rolled back.'
    }
}

function Get-ManifestData {
    <#
    .SYNOPSIS
        Returns the data in manifest text.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    $file = 'manifest-' + [guid]::NewGuid().ToString('N') + '.psd1'
    $path = Join-Path -Path ([Path]::GetTempPath()) -ChildPath $file
    try {
        [File]::WriteAllText($path, $Text, [UTF8Encoding]::new($false))
        return Import-PowerShellDataFile -LiteralPath $path
    }
    finally {
        Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    }
}

function Get-ModuleListing {
    <#
    .SYNOPSIS
        Returns the entry Home and the sidebar list for a module.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Version,

        [AllowEmptyString()]
        [string]$Description
    )

    return [PSCustomObject]@{
        Name        = $Name
        Version     = $Version
        Description = $Description
    }
}

function Get-ListedModule {
    <#
    .SYNOPSIS
        Returns every module that Home and the sidebar list, A to Z: those
        with a folder in the wiki, and the one being written.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Repository,

        [Parameter(Mandatory)]
        [string]$Wiki,

        [Parameter(Mandatory)]
        [PSCustomObject]$Current
    )

    $byName = [SortedDictionary[string, PSCustomObject]]::new([StringComparer]::OrdinalIgnoreCase)
    $byName[$Current.Name] = $Current
    $entries = Get-ChildItem -LiteralPath $Wiki -Directory
    $folders = @($entries | Where-Object { $_.Name -notlike '.*' })
    foreach ($folder in $folders) {
        $name = $folder.Name
        $overview = Join-Path -Path $folder.FullName -ChildPath "$name.md"
        if ($name -ceq $Current.Name -or -not (Test-ShortModuleName -Name $name) -or
            -not (Test-Path -LiteralPath $overview -PathType Leaf)) {
            continue
        }

        $versions = @(Get-ReleaseVersion -Repository $Repository -Name $name)
        if ($versions.Count -eq 0) {
            throw "The wiki has pages for $name, but the repository has no release tag for it; " +
            'remove its folder from the wiki.'
        }

        $full = Resolve-ModuleName -Name $name
        $tag = Get-ReleaseTag -Module $name -Version $versions[0]
        $manifest = & git -C $Repository show "${tag}:src/$full/$full.psd1"
        if ($LASTEXITCODE -ne 0) {
            throw "git could not read the manifest of $name at $tag (exit $LASTEXITCODE)."
        }

        $data = Get-ManifestData -Text ($manifest -join "`n")
        $description = [string]$data.Description
        $listing = Get-ModuleListing -Name $name -Version $versions[0] -Description $description
        $byName[$name] = $listing
    }

    return $byName.Values
}

function Assert-PageName {
    <#
    .SYNOPSIS
        Refuses a page name that could not be a page, that the generator keeps
        for itself, that two new pages share, or that the wiki already uses. A
        name is the same in any case, and wherever the file is.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Wiki,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string[]]$Page
    )

    $taken = @{}
    $all = Get-ChildItem -LiteralPath $Wiki -Recurse -File -Filter '*.md'
    foreach ($file in $all) {
        $relative = [Path]::GetRelativePath($Wiki, $file.FullName).Replace('\', '/')
        $own = $relative.StartsWith("$Name/", [StringComparison]::Ordinal) -or
        $relative -ceq "$Name-Changelog.md"
        $skip = $own -or $relative.StartsWith('.git/', [StringComparison]::Ordinal) -or
        $file.BaseName.StartsWith('_', [StringComparison]::Ordinal)
        if (-not $skip) {
            $taken[$file.BaseName.ToUpperInvariant()] = $relative
        }
    }

    $seen = @{}
    foreach ($page in $Page) {
        if ($page -cnotmatch '^[A-Za-z0-9][A-Za-z0-9.-]*\z') {
            throw "'$page' could not be the name of a wiki page: a name is letters, " +
            'digits, dots and hyphens, starting with a letter or a digit.'
        }

        $key = $page.ToUpperInvariant()
        if ($key -ceq 'HOME') {
            throw "A page of $Name would be named '$page', " +
            "which the generator keeps for the wiki's home page."
        }

        if ($seen.ContainsKey($key)) {
            throw "Two pages of $Name would be named '$page'; " +
            'a wiki page is addressed by its name alone.'
        }

        $seen[$key] = $true
        if ($taken.ContainsKey($key)) {
            throw "The page '$page' would take the name of '$($taken[$key])'; " +
            'a wiki page is addressed by its name alone.'
        }
    }
}

function Assert-ReadmeLink {
    <#
    .SYNOPSIS
        Refuses a README that links to a file or a folder: it is shown on the
        wiki as well as in the package, where a relative link leads nowhere.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Module,

        [Parameter(Mandatory)]
        [string]$Readme
    )

    $text = [regex]::Replace($Readme, '(?s)(`{3,}|~{3,}).*?\1', '')
    $text = [regex]::Replace($text, '`[^`\r\n]*`', '')
    $inline = [regex]::Matches($text, '\]\(\s*<?([^)\s>]+)')
    $definitions = [regex]::Matches($text, '(?m)^\s{0,3}\[[^\]]+\]:\s*<?(\S+)')
    $targets = @($inline) + @($definitions) | ForEach-Object { $_.Groups[1].Value }
    $web = '^(https?://|mailto:|#)'
    $relative = @($targets | Where-Object { $_ -notmatch $web } | Select-Object -Unique)
    if ($relative.Count -gt 0) {
        $shown = ($relative | Select-Object -First 3) -join ', '
        throw "The README of $Module links to $shown, " +
        'which leads nowhere on the wiki; a README holds web addresses only.'
    }
}

function Read-ModulePackage {
    <#
    .SYNOPSIS
        Extracts a package and returns what its pages are made from: the
        manifest, the help of every exported function, the README and the
        changelog.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Package,

        [Parameter(Mandatory)]
        [string]$Module,

        [Parameter(Mandatory)]
        [string]$SourceRoot,

        [Parameter(Mandatory)]
        [string]$Work
    )

    $folder = Join-Path -Path $Work -ChildPath $Module
    Expand-Package -Package $Package -Destination $folder
    $manifestPath = Join-Path -Path $folder -ChildPath "$Module.psd1"
    $changelog = [File]::ReadAllText((Join-Path -Path $folder -ChildPath 'CHANGELOG.md'))
    if ($changelog.IndexOf('## [', [StringComparison]::Ordinal) -lt 0) {
        throw "The changelog in the package of $Module holds no release."
    }

    $readme = [File]::ReadAllText((Join-Path -Path $folder -ChildPath 'README.md'))
    Assert-ReadmeLink -Module $Module -Readme $readme
    $help = Get-ModuleHelpData -Manifest $manifestPath -SourceRoot $SourceRoot -Work $Work
    return [PSCustomObject]@{
        Manifest  = Import-PowerShellDataFile -LiteralPath $manifestPath
        Help      = @($help)
        Readme    = $readme
        Changelog = $changelog
    }
}

function Get-ModulePage {
    <#
    .SYNOPSIS
        Returns the text of every page of a module's folder, by path from the
        wiki's root, in the order they are written.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [PSCustomObject]$Content
    )

    $help = $Content.Help
    $command = [string[]]@($help | ForEach-Object Name)
    $pages = [ordered]@{}
    foreach ($entry in $help) {
        $page = Format-CommandPage -Help $entry -ModuleName $Name -Command $command
        $pages["$Name/$($entry.Name).md"] = $page
    }

    $overview = Format-ModuleOverview -ModuleName $Name -Readme $Content.Readme -Help $help
    $pages["$Name/$Name.md"] = $overview
    $pages["$Name/$Name-Changelog.md"] = Format-ChangelogPage -Changelog $Content.Changelog
    $pages["$Name/_Sidebar.md"] = Format-ModuleSidebar -ModuleName $Name -Command $command
    return $pages
}

function Write-WikiFile {
    <#
    .SYNOPSIS
        Writes a page as UTF-8 without a byte order mark, with LF line endings
        and one final newline, refusing a path outside the wiki.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Wiki,

        [Parameter(Mandatory)]
        [string]$RelativePath,

        [Parameter(Mandatory)]
        [string]$Text
    )

    $path = [Path]::GetFullPath((Join-Path -Path $Wiki -ChildPath $RelativePath))
    $what = "The page '$RelativePath' would be written outside the wiki"
    Assert-InsideFolder -Folder $Wiki -Path $path -Description $what
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force
    $body = ($Text -replace "`r`n", "`n").TrimEnd("`n") + "`n"
    [File]::WriteAllText($path, $body, [UTF8Encoding]::new($false))
}

function Clear-ModulePage {
    <#
    .SYNOPSIS
        Removes a module's folder from the wiki, and its changelog page at the
        wiki's root, where earlier releases put it.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Wiki,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $folder = Join-Path -Path $Wiki -ChildPath $Name
    if (Test-Path -LiteralPath $folder) {
        Remove-Item -LiteralPath $folder -Recurse -Force
    }

    $legacy = Join-Path -Path $Wiki -ChildPath "$Name-Changelog.md"
    if (Test-Path -LiteralPath $legacy -PathType Leaf) {
        Remove-Item -LiteralPath $legacy -Force
    }
}

function Save-WikiChange {
    <#
    .SYNOPSIS
        Stages the wiki and commits it as the GitHub Actions bot, when
        anything changed. Returns whether a commit was made.
    #>
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Wiki,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Version
    )

    $identity = @(
        '-c', 'core.autocrlf=false'
        '-c', 'core.safecrlf=false'
        '-c', 'user.email=41898282+github-actions[bot]@users.noreply.github.com'
        '-c', 'user.name=github-actions[bot]'
    )
    & git -C $Wiki @identity add --all -- .
    if ($LASTEXITCODE -ne 0) {
        throw "git could not stage the wiki pages (exit $LASTEXITCODE)."
    }

    $changed = @(& git -C $Wiki diff --cached --name-only).Count -gt 0
    if ($changed) {
        & git -C $Wiki @identity commit -q -m "docs: update the $Name wiki pages for $Version"
        if ($LASTEXITCODE -ne 0) {
            throw "git could not commit the wiki pages (exit $LASTEXITCODE)."
        }
    }

    return $changed
}

$repository = [Path]::GetFullPath($RepositoryPath)
if (-not $SourceRoot) {
    $SourceRoot = Join-Path -Path $repository -ChildPath 'src'
}

$wiki = [Path]::GetFullPath($WikiPath)
& git -C $wiki rev-parse --git-dir *> $null
if ($LASTEXITCODE -ne 0) {
    throw "'$wiki' is not a git repository."
}

$uncommitted = @(& git -C $wiki status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw "git could not read the state of the wiki clone (exit $LASTEXITCODE)."
}

if ($uncommitted.Count -gt 0) {
    throw "The wiki clone at '$wiki' has $($uncommitted.Count) uncommitted change(s); " +
    'everything in it is committed, so it must be clean.'
}

$packageFile = [Path]::GetFullPath($Package)
$identity = & (Join-Path -Path $PSScriptRoot -ChildPath 'Get-PackageIdentity.ps1') `
    -Path $packageFile
if ($identity.Version -cne $identity.ManifestVersion) {
    throw "The package says $($identity.Version) but its manifest says " +
    $identity.ManifestVersion
}

$module = Resolve-ModuleName -Name $identity.Id
$name = Get-ShortModuleName -Module $module
$version = $identity.Version
Assert-NewestRelease -Repository $repository -Name $name -Version $version

$workName = 'wiki-' + [guid]::NewGuid().ToString('N')
$work = Join-Path -Path ([Path]::GetTempPath()) -ChildPath $workName
try {
    $content = Read-ModulePackage -Package $packageFile -Module $module -SourceRoot $SourceRoot `
        -Work $work
    Assert-HelpComplete -Module $module -Help $content.Help
    $command = [string[]]@($content.Help | ForEach-Object Name)
    $pageNames = @($command) + @($name, "$name-Changelog")
    Assert-PageName -Wiki $wiki -Name $name -Page $pageNames

    $description = [string]$content.Manifest.Description
    $current = Get-ModuleListing -Name $name -Version $version -Description $description
    $listed = @(Get-ListedModule -Repository $repository -Wiki $wiki -Current $current)
    $pages = Get-ModulePage -Name $name -Content $content
    $pages['Home.md'] = Format-Home -ListedModule $listed
    $pages['_Sidebar.md'] = Format-RootSidebar -ListedModule $listed
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Clear-ModulePage -Wiki $wiki -Name $name
foreach ($path in $pages.Keys) {
    Write-WikiFile -Wiki $wiki -RelativePath $path -Text $pages[$path]
}

$changed = Save-WikiChange -Wiki $wiki -Name $name -Version $version
return [PSCustomObject]@{
    Module  = $name
    Version = $version
    Pages   = $command.Count
    Changed = $changed
}
