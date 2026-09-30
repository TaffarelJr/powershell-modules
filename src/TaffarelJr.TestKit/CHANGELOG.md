# Changelog

The format follows [Keep a Changelog][changelog], and the module follows
[Semantic Versioning][semver].

## [Unreleased]

### Added

- Initial release: `Assert-That`, `Assert-Equal`, `Assert-Throws`,
  `Complete-TestRun`, `Skip-TestRun`, `Get-HostOutput`, `Get-WarningOutput`,
  `Get-WhatIfOutput`, and `Use-SplitLocation`.
- A skipped file prints `skipped - <reason>`, and an empty file accepted by
  `Complete-TestRun -AllowEmpty` prints
  `allowed empty - checks run by other means`, each before its tally line.
- `Use-ReplacedFunction`, which stands a stub in for one of a module's
  functions while a block runs and puts the original back.

### Changed

- A block handed to `Assert-Throws`, `Get-HostOutput`, `Get-WarningOutput` or
  `Get-WhatIfOutput` runs with `$ErrorActionPreference` set to `Stop`, so a
  non-terminating error it writes counts as a throw, or fails the capture.

### Fixed

- `Assert-Throws` looks at every inner exception of an `AggregateException`,
  not only the first.

<!-- Public URIs (alphabetical) -->

[changelog]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
