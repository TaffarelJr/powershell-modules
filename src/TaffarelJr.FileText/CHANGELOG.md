# Changelog

The format follows [Keep a Changelog][changelog], and the module follows
[Semantic Versioning][semver].

## [Unreleased]

### Added

- Initial release: encoding/line-ending-preserving `Read-TextFile`/
  `Write-TextFile` (backed by `Get-FileEncoding`/ `Get-LineEnding`), and
  `Rename-Token`/ `Update-FileToken` for replacing a placeholder across a
  directory tree's content, file names, and directory names. `Read-TextFile`,
  `Get-FileEncoding`, and `Update-FileToken` take path strings, `Resolve-Path`
  output, and files from `Get-ChildItem` piped in. `Write-TextFile`,
  `Rename-Token`, and `Update-FileToken` support `-WhatIf` and `-Confirm`. With
  `-Verbose`, they name each file they write and each item they rename, never a
  file's text.
- `Write-TextFile -CreateDirectory`, which makes the folders missing on the
  way to the file before it writes.

<!-- Public URIs (alphabetical) -->

[changelog]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
