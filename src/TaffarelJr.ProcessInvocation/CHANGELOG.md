# Changelog

The format follows [Keep a Changelog][changelog], and the module follows
[Semantic Versioning][semver].

## [Unreleased]

### Added

- Initial release: `Invoke-NativeCommand` (captures output, throws with detail
  on failure), `Invoke-NativeRead` (reports success, whether the command
  started, and its output instead of throwing for anything the command does, and
  resets `$LASTEXITCODE`), `Assert-ExitCode` (a plain throw-if-nonzero check for
  a command whose output already streamed to the console), `Hide-UrlCredential`
  (the credential a URL carries, hidden in any text, as every failure message
  here hides it), and `Hide-MaskedValue` (the values a caller names, hidden in
  any text). `-Mask` on both invokers hides such values in every message and in
  the verbose line. `-Verbose` shows the command line, credentials hidden,
  before a call runs.
- `Invoke-NativeCommand -HideOutput`, which leaves what the command printed out
  of the failure message.

<!-- Public URIs (alphabetical) -->

[changelog]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
