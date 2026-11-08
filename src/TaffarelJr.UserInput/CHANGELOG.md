# Changelog

The format follows [Keep a Changelog][changelog], and the module follows
[Semantic Versioning][semver].

## [Unreleased]

### Added

- Initial release: prompting primitives (`Read-Input`, `Read-Secret`),
  validation (`Assert-Input`), environment-variable access
  (`Get-EnvironmentVariable`, and `Set-EnvironmentVariable` with `-WhatIf` and
  `-Confirm`), bounded retry (`Invoke-InputRetry`), confirmation
  (`Confirm-Input`, `Confirm-Proceed`), menu selection (`Select-Choice`),
  host-interactivity detection (`Test-InteractiveHost`), and a CI-safe pause
  (`Wait-KeyPress`).

<!-- Public URIs (alphabetical) -->

[changelog]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
