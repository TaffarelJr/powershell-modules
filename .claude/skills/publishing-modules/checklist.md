# Gallery publishing checklist

Walk it for each module before its first publish, and the release items again
for every version. `SKILL.md` says why each item matters.

## Name and manifest

- [ ] `Find-PSResource -Name TaffarelJr.<Name> -Repository PSGallery` finds
      nothing, or only our own versions.
- [ ] The `.psd1` file name, the module folder name and the module name are the
      same: the Gallery's package id is the `.psd1` file name.
- [ ] `ModuleVersion` is three numbers and higher than any published version.
- [ ] `GUID` is the module's own and never changes.
- [ ] `Description` stands alone as the page text, and `Author`, `CompanyName`
      and `Copyright` are filled in.
- [ ] `PowerShellVersion = '7.4'` and `CompatiblePSEditions = @('Core')`.
- [ ] `FunctionsToExport`, `CmdletsToExport`, `VariablesToExport` and
      `AliasesToExport` are literal lists (empty is `@()`), never `'*'`.
- [ ] `RequiredModules` gives each dependency a `ModuleVersion` (a minimum), or
      a `RequiredVersion` where the owner pinned it, and each one is on the
      Gallery as a stable version at that version or higher.
- [ ] `PrivateData.PSData.Tags` has `PSEdition_Core`, a platform tag (`Windows`,
      `Linux`, `MacOS`) only for a platform the tests passed on, and a few
      common single-word tags with no blank in any of them.
- [ ] `ProjectUri`, `LicenseUri` and `ReleaseNotes` resolve; `IconUri`, if set,
      is a direct link to an 85x85 image with a transparent background, not a
      web page and not a file in the package.
- [ ] `Prerelease` is set only for a prerelease: ASCII letters and digits,
      starting with a letter, on a three-part `ModuleVersion` no stable release
      has used.
- [ ] `FileList`, `ModuleList`, `HelpInfoURI`, `DefaultCommandPrefix` and
      `RequireLicenseAcceptance` are not set.

## Commands and help

- [ ] Every verb is approved and every noun singular.
- [ ] Every state-changing function supports `-WhatIf` and `-Confirm`.
- [ ] No `Write-Host` outside a module whose purpose is host output, and each
      suppression there has a true justification.
- [ ] Every exported function has `.SYNOPSIS`, `.DESCRIPTION`, a `.PARAMETER`
      per parameter, an `.EXAMPLE`, `.OUTPUTS` and a `.LINK`.
- [ ] The README has the install line, a usage example, `Errors` and
      `Name collisions`; the CHANGELOG has an entry for this version.

## Checks

- [ ] `Test-ModuleManifest -ErrorAction Stop` passes, with `src` on
      `PSModulePath` for a module that has `RequiredModules`.
- [ ] The analyzer is clean with the repo's settings.
- [ ] `Invoke-Tests.ps1 -Module <Name> -Integration -Coverage` passes:
      integration tests included, reports written.
- [ ] `Compress-PSResource` produces the package and its file list is exactly
      what the module ships: nothing in the folder that is not part of the
      module.
- [ ] A publish to a local folder repository saves and imports in a clean
      session (the folder checks no key and no dependency).

## Release

- [ ] The CHANGELOG's `Unreleased` items move under `## [X.Y.Z] - YYYY-MM-DD`,
      the file says it follows Semantic Versioning, and a yanked version is
      marked `[YANKED]`.
- [ ] Dependencies are published first, and a version already on the Gallery is
      skipped, never pushed again.
- [ ] The publish runs in CI with `-Repository PSGallery`, the API key comes
      from an environment secret, and the key has the scope "Push new or
      update packages", the glob `TaffarelJr.*`, and an expiry that is in the
      tracking issue.
- [ ] The tag `<ModuleName>/vX.Y.Z` points at the published commit.
- [ ] The root README's version column shows the published version.

## After the publish

- [ ] The package page shows the expected version, description, tags and
      links; the module installs into a clean session; after the first publish
      the page lists the functions and `Find-PSResource -CommandName` finds
      them.
- [ ] The account's mailbox is watched for the Gallery's scan results.

## Sources

- [Publishing guidelines and best practices][guidelines]
- [Creating and publishing an item][publishing]
- [Package metadata values that affect the Gallery UI][manifest-ui]
- [Modules with compatible PowerShell editions][psedition]
- [Packages with compatible editions or operating systems][by-compat]
- [Prerelease module versions][prerelease]
- [Modules requiring license acceptance][license-acceptance]
- [Unlisting packages][unlisting]
- [Managing API keys][apikeys]
- [about_Module_Manifests][about-manifests]
- [Publish-PSResource][publish-psresource]
- [Compress-PSResource][compress-psresource]
- [Install-PSResource][install-psresource]
- [Test-ModuleManifest][test-manifest]
- [about_Comment_Based_Help][comment-help]
- [PSScriptAnalyzer rules and recommendations][pssa-rules]
- [Using PSScriptAnalyzer][pssa-using]
- [The PSGallery analyzer preset][pssa-gallery]
- [PSResourceGet source: packing and signing][psresourceget-source]
- [PlatyPS overview][platyps]
- [New-FileCatalog][file-catalog]
- [Using secrets in GitHub Actions][gh-secrets]
- [Using environments for deployment][gh-environments]
- [Keep a Changelog 1.1.0][changelog]
- [Semantic Versioning 2.0.0][semver]

[guidelines]: https://learn.microsoft.com/powershell/gallery/concepts/publishing-guidelines
[publishing]: https://learn.microsoft.com/powershell/gallery/how-to/publishing-packages/publishing-a-package
[manifest-ui]: https://learn.microsoft.com/powershell/gallery/concepts/package-manifest-affecting-ui
[psedition]: https://learn.microsoft.com/powershell/gallery/concepts/module-psedition-support
[by-compat]: https://learn.microsoft.com/powershell/gallery/how-to/finding-packages/searching-by-compatibility
[prerelease]: https://learn.microsoft.com/powershell/gallery/concepts/module-prerelease-support
[license-acceptance]: https://learn.microsoft.com/powershell/gallery/concepts/module-license-acceptance
[unlisting]: https://learn.microsoft.com/powershell/gallery/how-to/publishing-packages/unlisting-packages
[apikeys]: https://learn.microsoft.com/powershell/gallery/how-to/managing-profile/creating-apikeys
[about-manifests]: https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_module_manifests
[publish-psresource]: https://learn.microsoft.com/powershell/module/microsoft.powershell.psresourceget/publish-psresource
[compress-psresource]: https://learn.microsoft.com/powershell/module/microsoft.powershell.psresourceget/compress-psresource
[install-psresource]: https://learn.microsoft.com/powershell/module/microsoft.powershell.psresourceget/install-psresource
[test-manifest]: https://learn.microsoft.com/powershell/module/microsoft.powershell.core/test-modulemanifest
[comment-help]: https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_comment_based_help
[pssa-rules]: https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/rules-recommendations
[pssa-using]: https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer
[pssa-gallery]: https://github.com/PowerShell/PSScriptAnalyzer/blob/main/Engine/Settings/PSGallery.psd1
[psresourceget-source]: https://github.com/PowerShell/PSResourceGet/tree/master/src/code
[platyps]: https://learn.microsoft.com/powershell/utility-modules/platyps/overview
[file-catalog]: https://learn.microsoft.com/powershell/module/microsoft.powershell.security/new-filecatalog
[gh-secrets]: https://docs.github.com/actions/security-guides/using-secrets-in-github-actions
[gh-environments]: https://docs.github.com/actions/deployment/targeting-different-environments/using-environments-for-deployment
[changelog]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
