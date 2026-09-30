# Changelog

The format follows [Keep a Changelog][changelog], and the module follows
[Semantic Versioning][semver].

## [Unreleased]

### Added

- Initial release: indent-aware line printers (`Write-Success`, `Write-Skip`,
  `Write-Warn`, `Write-Failure`, `Write-Info`, `Write-Detail`, `Write-Field`,
  `Write-Doing`, `Write-Done`), step tracking (`Write-Step`, `Clear-Step`,
  `Get-CurrentStep`), box drawing (`Write-Header`, `Write-Banner`), the indent
  primitives (`Push-Indent`, `Pop-Indent`, `Get-Indent`, `Invoke-Indented`), and
  the exported `$DefaultIndentWidth` for aligning a caller's own output.
- `Write-Done -Warn`, a yellow outcome for a step that is neither done nor
  already done, such as "would create"; it cannot be combined with `-Skip`.
- `Invoke-Doing`, which announces a step, runs a script block, and closes the
  line with the string the block returns, or "failed" when it throws.

<!-- Public URIs (alphabetical) -->

[changelog]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
