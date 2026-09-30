---
name: publishing-modules
description: >-
  What a module from this repo must get right before it goes to the
  PowerShell Gallery, so it installs cleanly and looks professional: a
  complete manifest and PSData, explicit exports, full help, README and
  CHANGELOG, semantic and prerelease versions, dependencies published first,
  signing, and a CI publish with the API key held as a secret. Use when
  preparing a module for its first publish, publishing a new version, setting
  up the publish workflow, or reviewing a manifest for the Gallery.
when_to_use: >-
  Trigger phrases: publish to the Gallery, PowerShell Gallery,
  Publish-PSResource, release a module, prerelease, API key, IconUri,
  ReleaseNotes, Test-ModuleManifest, sign the module, publish workflow.
---

# Publishing modules

Nothing is published yet: every module stays `0.1.0` until the owner starts
real Gallery publishing (`repo-workflow`). This skill is what that first
publish, and every one after it, must get right. `checklist.md` is the list to
walk for a module; it cites the documentation behind each item.

A Gallery version is permanent. It can be unlisted, so it no longer shows in
search, but it stays installable by exact version and can never be replaced:
the next publish must carry a higher version. Page metadata (icon, tags, notes)
can be corrected on the Gallery's edit page without a new version, but then
page and manifest disagree, so the next version carries the same change. A
version is removed only by the Gallery's administrators, for infringing,
harmful or sensitive content; a published secret is that case, after the secret
is revoked. A bad version that stays is unlisted and marked `[YANKED]` in the
CHANGELOG. Get it right before pushing, not after.

## The manifest is the Gallery page

The Gallery builds the package page from the manifest: description, author,
copyright, tags, exported commands, editions, minimum PowerShell version,
dependencies, release notes, and the project, license and icon links. It does
not render the README, so `Description` must stand alone: one or two sentences
a stranger understands. A gap in the manifest is a gap on the page, and almost
nothing reports one: the packer refuses only a missing `Author` or
`Description`, the analyzer's `PSMissingModuleManifestField` flags only a
missing `ModuleVersion`, and no tool notices a missing link, tag or icon. The
checklist is the check.

- `Author`, `CompanyName` and `Copyright` follow `module-structure`.
- `PowerShellVersion = '7.4'` and `CompatiblePSEditions = @('Core')` match the
  `#Requires` line, and the tag `PSEdition_Core` says the same: the tag is what
  the Gallery's edition filter reads, the packer does not derive it, and a
  package without one is treated as Desktop-compatible. Add `Windows`, `Linux`
  or `MacOS` (that spelling) only for a platform the tests passed on. A tag is
  one word; the packer splits a phrase into several tags, so a phrase people
  search for goes in `Description`.
- `PrivateData.PSData`: `Tags`, `ProjectUri`, `LicenseUri`, `ReleaseNotes`, and
  `IconUri` once the project has an icon: a direct link to an 85x85 image with
  a transparent background, never a web page (a GitHub `blob` address is one)
  and never a file in the package. `LicenseUri` is what keeps the Gallery's own
  terms from applying to the package; the root `LICENSE` is not packed, so the
  link is the only license the page shows. `Prerelease` only for a prerelease.
- Exports are literal lists, never `'*'`: the Gallery lists them, and discovery
  and import are faster when PowerShell need not load the module to find out.
- `RequiredModules` names each dependency with `ModuleVersion`, which is a
  minimum (the package says `0.1.0`, meaning that version or higher). Only
  `RequiredVersion` pins, and `ModuleVersion` with `MaximumVersion` is a range.
  `Publish-PSResource` itself looks each dependency up in the target repository
  before it pushes, counting prereleases, so modules go out in dependency
  order and a stable module never depends on a prerelease-only one.
- Leave unset, each for a reason: `FileList` and `ModuleList` (the Gallery
  builds its own file list, and `Test-ModuleManifest` fails on a stale entry),
  `HelpInfoURI` (updatable XML help only), `DefaultCommandPrefix` (a consumer
  picks `-Prefix`, as each README says) and `RequireLicenseAcceptance` (it
  needs a `license.txt` in the module root and makes every unattended install,
  dependents included, fail without `-AcceptLicense`).

## The commands are the product

- Approved verbs (`Get-Verb`) and singular nouns: the Gallery's analyzer preset
  checks both, and an unapproved verb makes `Import-Module` warn.
- A function that changes state supports `-WhatIf` and `-Confirm`
  (`public-function-contract`).
- No `Write-Host` for data or progress: it bypasses the output pipeline, so a
  caller cannot take the text as a result. The analyzer's `PSAvoidUsingWriteHost`
  is a default rule, not a Gallery one. A module whose purpose is host output
  (`TaffarelJr.ConsoleOutput`) suppresses it where it applies, with a
  justification.
- Every exported function has full comment-based help: `.SYNOPSIS`,
  `.DESCRIPTION`, a `.PARAMETER` for every parameter, at least one `.EXAMPLE`,
  `.OUTPUTS`, and a `.LINK` to the module's README so `Get-Help -Online` lands
  somewhere. Comment-based help is enough; external XML help built with
  `Microsoft.PowerShell.PlatyPS` is worth it only for updatable or translated
  help.
- Each module's `README.md` and `CHANGELOG.md` sit inside its folder
  (`module-structure`), so they travel in the package and appear in its file
  list; the README's install line names the exact Gallery name.

## Versions and release notes

- Semantic Versioning: `MAJOR.MINOR.PATCH`, three numbers. A `0.y.z` module is
  in initial development and may change at any time; `1.0.0` is the first
  promise of a stable public API. After that, a breaking change to a command,
  parameter or output is a major version.
- A prerelease keeps a plain three-part `ModuleVersion` and puts its label in
  `PrivateData.PSData.Prerelease` (`'preview1'`): ASCII letters and digits,
  starting with a letter, no dot, no `+`, no leading hyphen. The packer checks
  none of this (a dot goes through, a `+build` part is dropped), so the
  checklist does. Labels sort as text, and a stable version outranks every
  prerelease of the same number, so a prerelease of a number already published
  stable is refused: decide before the first publish whether `0.1.0` is
  preceded by a `0.1.0` preview. Callers need `-Prerelease` to see one.
- Each module's `CHANGELOG.md` follows Keep a Changelog from the first publish:
  `## [Unreleased]` at the top, then one `## [X.Y.Z] - YYYY-MM-DD` per release,
  newest first, with `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed` and
  `Security` groups, and a line saying the module follows Semantic Versioning.
  `ReleaseNotes` is shown as given; a link to the `main` CHANGELOG shows every
  version the same, newest, file, which is the trade-off this repo accepts.
- The release tag is `<ModuleName>/vX.Y.Z` (`module-structure`).

## What an install looks like

- `Install-PSResource` puts a module at `<modules root>/<Name>/<ModuleVersion>`
  in `CurrentUser` scope by default, with no elevation. A new version lands
  beside the old one, and `Import-Module` takes the highest. A prerelease lives
  in the folder of its three-part version, so `0.2.0-preview1` and `0.2.0`
  replace one another.
- Two versions can be loaded into one process, and whatever a module keeps at
  process scope (`[AppDomain]` data) is shared between them. Put the shape of
  the state into the slot name and change it when the shape changes, as
  `TaffarelJr.Tally` does.
- A root `.psm1` that dot-sources one file per function pays for each file at
  import: on a machine whose security software scans every script file that
  is a fraction of a second per file, so a module of a few dozen functions
  takes seconds to import where the same code in one file takes a fraction of
  one. The repository keeps the file-per-function layout as its source; whether
  the publish step builds a single `.psm1` (`Private` then `Public`,
  `using namespace` lines hoisted, the same literal exports) is decided before
  the first publish and recorded here.

## Publishing

- `Publish-PSResource` runs `Test-ModuleManifest` itself, and that fails when a
  `RequiredModules` entry is not installed in the session. In CI put `src` on
  `PSModulePath` first, or install the dependency from the Gallery; never
  `-SkipModuleManifestValidate`, which skips the other checks too. Run
  `Test-ModuleManifest -ErrorAction Stop` the same way beforehand: without
  `-ErrorAction Stop` a manifest with errors still returns a module object. It
  proves the listed files exist and the manifest loads; it does not check the
  Gallery's fields.
- Run the analyzer on `src` with the repo's settings. The Gallery scans every
  package with PSScriptAnalyzer and mails the account about what it finds; its
  `PSGallery` preset is a subset of the rules the repo's settings already run,
  so a second run adds nothing.
- Pack first with `Compress-PSResource -Path src/<ModuleName>`: it runs the
  publish step's manifest check and packing with no repository, and the
  `.nupkg` is a zip whose file list must be exactly what the module ships. Then
  rehearse against a local folder repository (`Register-PSResourceRepository`),
  save from it into a clean session, and import. A folder repository checks
  neither the API key nor the dependencies, and `Publish-PSResource -WhatIf`
  returns before any check, so neither proves the real publish will pass. The
  Gallery is not a place to test a publish.
- Publish from CI only, with
  `Publish-PSResource -Path src/<ModuleName> -Repository PSGallery`; without
  `-Repository` it goes to the highest-priority registered repository. It
  packs every file under the folder, with no exclude, so nothing that is not
  part of the module may sit in it; which dot
  files it drops depends on the PSResourceGet version, so pin that version in
  CI. The package id is the `.psd1` file name. A version already on the Gallery
  is refused, after packing, so a rerun after a partial release skips the
  modules already there and publishes the rest in dependency order.
- The API key is a GitHub Actions secret in an environment whose required
  reviewer is the owner, passed to the step through `env:`. Create it with the
  scope "Push new or update packages", a glob of `TaffarelJr.*`, and the
  longest expiry offered; a key always expires, so its renewal date goes in
  the tracking issue, and the Gallery mails the account before then. The value
  shows once. Never echo it, and never put it in the argument of a native
  command; `-ApiKey $env:NAME` is a cmdlet parameter.
- After the publish, open the package page, install the module into a clean
  session, check that the page lists the module's functions and that
  `Find-PSResource -CommandName <Command>` finds it (the packer writes none of
  the command tags PowerShellGet wrote; only a real publish shows whether the
  Gallery adds them), and watch the account's mailbox for the scan results.
- Signing is optional; the Gallery does not require it. An Authenticode
  signature on every `.ps1`, `.psm1` and `.psd1` is what
  `Install-PSResource -AuthenticodeCheck` verifies, on Windows only, file by
  file, so a signed
  catalog alone does not satisfy it; a catalog (`New-FileCatalog`, Windows
  only) serves PowerShellGet 2.x, and PowerShell never checks either at import.
  Until there is a code-signing certificate, publish unsigned and say so in the
  README.
