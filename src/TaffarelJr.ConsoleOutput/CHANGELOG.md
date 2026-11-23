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
- A progress line that is opened and later ended with how it went: `Show-Doing`
  announces work on a line it leaves open, `Show-Done` ends the line with
  "done", "already done" (`-Skip`) or a warning (`-Warn`), or with wording of
  its own, and `Invoke-Doing` does both around a script block, ending the line
  with "done", "failed" or "stopped" however the block ends. Every command that
  writes a line ends an open one first.
- `Show-Field`, which prints a name and its value as `Name: value` in gray at
  the current indent. `-Budget` sets the width of the name column, so the values
  of the fields that share it line up; a longer name is not cut. The entries of
  a dictionary and an object's `PSObject.Properties` pipe straight in.
- `Show-FieldList`, which prints a list, a dictionary, or an object as
  fields with the name column fitted to the longest name: a list by position,
  a dictionary by key (a hashtable sorted, any other dictionary in its own
  order), an object by its properties. A list, dictionary, or custom object
  inside another is printed as its name with its own fields one level in,
  down to `-Depth` levels (3 by default). `-Budget` fixes the top level's
  column. Piped values are the elements of a list, and nothing is printed
  until the input ends. A single value is listed as a list of one.

<!-- Public URIs (alphabetical) -->

[changelog]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
