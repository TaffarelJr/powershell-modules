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

<!-- Public URIs (alphabetical) -->

[changelog]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
