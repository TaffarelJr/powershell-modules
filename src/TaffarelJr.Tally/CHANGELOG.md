# Changelog

The format follows [Keep a Changelog][changelog], and the module follows
[Semantic Versioning][semver].

## [Unreleased]

### Added

- Initial release: tagged counters. Every tag is a counter of its own, and an
  add with no tag goes to a default counter, `(untagged)`. `Add-Tally` adds an
  amount to each tag it is given, `Get-Tally` returns the counters as objects
  with a `Name` and a `Value`, and `Clear-Tally` clears them. `Add-Tally` also
  merges in a dictionary of counts, or pairs from the pipeline, so what
  `Get-Tally` returns goes straight back in, in the same process or through
  JSON in another. The counts are kept for the whole process, shared by every
  runspace, and survive importing the module again.

<!-- Public URIs (alphabetical) -->

[changelog]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
