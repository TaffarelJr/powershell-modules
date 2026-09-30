# Changelog

The format follows [Keep a Changelog][changelog], and the module follows
[Semantic Versioning][semver].

## [Unreleased]

### Added

- Initial release: `Get-RequiredModule`, `Test-RequiredModule`,
  `Install-RequiredModule`, `Import-RequiredModule`, and
  `Assert-RequiredModule`. With `-Verbose`, `Install-RequiredModule` shows the
  `Install-Module` command before it runs.
- `Update-RequiredModule`, which brings the declared modules to the newest
  version the Gallery has, and installs any that is missing.
- A manifest entry, and a module object, may leave out `MinimumVersion`: a name
  alone means any version will do.

<!-- Public URIs (alphabetical) -->

[changelog]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
