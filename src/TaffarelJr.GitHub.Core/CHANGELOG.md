# Changelog

The format follows [Keep a Changelog][changelog], and the module follows
[Semantic Versioning][semver].

## [Unreleased]

### Added

- Initial release: `Invoke-GitHubCommand` (runs gh with its output captured),
  `Invoke-GitHubApi` and `Test-GitHubApi` (the raw REST/GraphQL escape hatch and
  a probe that reads "not there" as `$false`), `ConvertFrom-GitHubJson` and
  `ConvertTo-PascalCaseObject` (gh's JSON as PascalCase objects, strings kept as
  strings), `ConvertTo-GitHubFieldArgument`, `ConvertTo-GitHubCsvField`, and
  `ConvertTo-GitHubJsonFieldList` (gh's field and flag values),
  `Resolve-GitHubPath`, `Resolve-GitHubInputFile`,
  `ConvertTo-GitHubRepositoryReference`, `Resolve-GitHubRepositoryArgument`, and
  `Resolve-GitHubItemReference` (the paths and references gh is given),
  `Assert-GitHubHostname` and `Assert-GitHubSameRepository` (the checks every
  module shares), `Format-GitHubRepositoryName` (a repository's name to show,
  without any credential), `New-GitHubPoll`, `Assert-GitHubPollRead`,
  `Wait-GitHubPoll`, `Test-GitHubPollExpired`, and `Get-GitHubTimeoutMessage`
  (the polling policy every waiter shares, which ends a wait at its first failed
  read, and its timeout message), and `Use-GitHubTextFile` (a body handed to gh
  in a file, byte for byte). With `-Verbose`, `Invoke-GitHubCommand` and
  `Invoke-GitHubApi` write the gh command line before it runs, with the
  credential a URL carries hidden, and `Invoke-GitHubCommand -Mask` hides any
  other value a caller names.
- `Invoke-GitHubApi -WhatIf` and `-Confirm`, for a call that can change
  something.

<!-- Public URIs (alphabetical) -->

[changelog]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
