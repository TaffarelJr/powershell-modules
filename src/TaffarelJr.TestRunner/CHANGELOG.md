# Changelog

The format follows [Keep a Changelog][changelog], and the module follows
[Semantic Versioning][semver].

## [Unreleased]

### Added

- Initial release: `Invoke-TestRun`, `Invoke-TestFileProcess`, and
  `Import-LocalModule`. With `-Verbose`, `Invoke-TestRun` and
  `Invoke-TestFileProcess` show the command line of each test file's process
  before it starts.
- `-Coverage` on `Invoke-TestRun` and `Invoke-TestFileProcess`: the coverage
  and result reports are written, and Pester is needed, only when it is given.
  Without it each file runs on its own.
- `-Exclude` on `Invoke-TestRun`: patterns over the file name, in the same
  vocabulary as `-Filter`, keep matching files out of a run.
- Coverage is measured per module when the test tree mirrors the source tree:
  a file under `test/Thing` is measured over `src/Thing` alone.
- `-ThrottleLimit` defaults to the processor count.

<!-- Public URIs (alphabetical) -->

[changelog]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
