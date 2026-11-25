# Changelog

The format follows [Keep a Changelog][changelog], and the module follows
[Semantic Versioning][semver].

## [Unreleased]

### Added

- Initial release: what a text file is written in. `Get-LineEnding` returns the
  line ending a piece of text uses, and `Get-FileEncoding` returns the encoding
  a file is written in, from its byte order mark. `Read-TextFile` returns a
  file's content, encoding, and line ending together, decoded strictly so that
  text that is not valid in its encoding is refused rather than read with
  replacement characters. `Write-TextFile` writes text back in the encoding and
  line ending the file already had, from lines or as given, in place and in
  full or not at all; `-LikeFilePath` copies both from a sibling,
  `-CreateDirectory` makes the folders on the way, and `-WhatIf` and
  `-Confirm` apply. `Update-FileToken` replaces a token in one file's content,
  keeping its encoding and line ending and returning whether it rewrote the
  file; a file without the token is left alone, and binary content that holds
  it is declined with a warning rather than rewritten as text.

<!-- Public URIs (alphabetical) -->

[changelog]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
