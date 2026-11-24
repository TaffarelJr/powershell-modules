# Changelog

The format follows [Keep a Changelog][changelog], and the module follows
[Semantic Versioning][semver].

## [Unreleased]

### Added

- Initial release: tagged counters. `Add-Tally` adds an amount under any
  tags, `Get-Tally` returns the sum of the adds that carry every tag it is
  given, or of all of them, and `Clear-Tally` removes those adds. The counts
  are kept for the whole process, shared by every runspace, and survive
  importing the module again.

<!-- Public URIs (alphabetical) -->

[changelog]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
