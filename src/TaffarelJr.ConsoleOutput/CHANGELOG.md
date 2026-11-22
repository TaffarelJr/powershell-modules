# Changelog

The format follows [Keep a Changelog][changelog], and the module follows
[Semantic Versioning][semver].

## [Unreleased]

### Added

- Initial release: the indent for a script's console output, kept per
  runspace as a stack of levels. `Push-Indent` adds a level, `Pop-Indent`
  takes the latest one off, `Get-Indent` returns the indent as spaces,
  `Get-IndentSize` returns it as a number, and `Reset-Indent` takes every
  level off at once. `Invoke-Indented` runs a script block one level in and
  puts the indent back when the block ends, even when it throws. The exported
  `$DefaultIndentWidth` is the width a level has when none is given.
- Status lines, each written to the host at the current indent, behind its own
  marker and in its own color: `Show-Detail`, a continuation line that sits
  under the text of the line above it, `Show-Failure`, `Show-Info`,
  `Show-Skip`, `Show-Success` and `Show-Warning`.
- `Show-Banner` and `Show-Header`, which print text in cyan at the current
  indent, centered inside a full box or left-justified between two rules, as
  wide as the console or, with `-Trim`, as wide as the text.

<!-- Public URIs (alphabetical) -->

[changelog]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
