---
name: module-secrets
description: >-
  How this repo's module code and tests keep a secret out of command lines,
  messages, -WhatIf and -Verbose text, errors and test output: standard input
  or the child environment, Hide-UrlCredential, -Mask, and the surfaces a
  CredentialHiding or ValueMasking test must check. Use when writing or
  reviewing a function that takes a token, a password, a URL or caller text
  that may hold one, or a test that proves a secret stays hidden.
when_to_use: >-
  Trigger phrases: token parameter, securestring, mask a value, -Mask,
  Hide-UrlCredential, CredentialHiding test, ValueMasking test, leaking
  surface, secret in an error message.
---

# Secrets in module code

A secret that reaches a message has leaked: `$Error`, `Get-Error`, transcripts
and CI logs keep whatever was built. These rules keep it out at the source.
Keeping secrets out of a session, a probe or a push is the owner's
`handling-secrets` skill, where it is installed.

## In code

- A secret travels on standard input (`-StdIn` on the `Invoke-*` helpers), in
  the child's environment, or as a `[securestring]` parameter. Never as an
  argument: command lines show in process lists, in `Running:` verbose lines
  and in failure messages.
- Every message, `-WhatIf` target, `-Verbose` line, thrown text and
  `TargetObject` that can echo a value hides it, at the moment the message is
  built: `$Error` and `Get-Error` repeat whatever was built.
- Which helper hides what:
  - `Hide-UrlCredential` (ProcessInvocation) hides a URL's user information. It
    does not hide a token in a query string, and bare `token@host` only in some
    positions.
  - `-Mask` on the `Invoke-*` helper that runs the tool hides any other value
    that may be secret (`Hide-MaskedValue` underneath; a value under four
    characters is not masked).
  - `Hide-GitHubCredential` is private to `GitHub.Core`; other modules use the
    two above.
- Hide at the source of the value, before it is spliced into a sentence: a
  scheme-less `user:token@host` hides everything from the start of the text up
  to the `@`, so hide the piece, not the sentence.
- PowerShell's default error view quotes the line of the calling script, so a
  secret written literally there (`-Value 'x'`) is shown. Callers pass a
  variable or a `SecureString`; each README says so.
- Never log request or response bodies or headers. `Invoke-GitHubApi` masks
  header values and the values of fields named like a secret; a real secret
  goes in `-Body`, which travels on standard input.
- A layered helper must not let the layer below print the raw command line the
  layer above masked (`public-function-contract`, Verbose).

## In tests

- Assert the sentinel the test passed in (a fake value such as
  `SENTINEL_SECRET_123`) is absent from every surface the secret could reach:
  the message, `TargetObject`, `$Error[0]`, the `Out-String` of the record, the
  verbose stream, `-WhatIf` text and standard output. Also assert the useful
  words of the message are still there, or a mask that blanks the whole
  message passes. The `Get-LeakingSurface` fixtures walk the surfaces.
- Compare sentinels, never real secrets: `Assert-Equal` prints both sides.
