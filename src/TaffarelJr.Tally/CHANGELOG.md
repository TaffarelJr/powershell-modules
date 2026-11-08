# Changelog

The format follows [Keep a Changelog][changelog], and the module follows
[Semantic Versioning][semver].

## [Unreleased]

### Added

- Initial release: named counters (`Add-Tally`, `Get-Tally`, `Clear-Tally`),
  each optionally isolated under its own `-Key` namespace, a string renderer
  (`Format-Tally`), and a parser (`Read-Tally`) that reads one back. Counters
  are process-wide and last as long as the process does; a piped `Name`/ `Count`
  object adds at its own count, so `Read-Tally` output merges straight into
  `Add-Tally`.

<!-- Public URIs (alphabetical) -->

[changelog]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
