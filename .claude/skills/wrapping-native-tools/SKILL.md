---
name: wrapping-native-tools
description: >-
  How to wrap a command-line tool (git, gh, any native command) in a module so
  it never hangs, injects options, merges stderr into data, reads a failure as
  an answer or leaks a secret: the ProcessInvocation layers, one helper per
  tool, operands, unattended runs, output parsing and exit codes. Use when
  adding, changing or reviewing a function that runs a native tool.
when_to_use: >-
  Trigger phrases: wrap a CLI, Invoke-NativeCommand, Invoke-GitCommand,
  Invoke-GitHubCommand, gh flag, git flag, editor opened, option injection,
  parse output.
---

# Wrapping native tools

A fake-tool test only pins the argument vector the code builds, so check a flag
against `<tool> --help` and the tool's source when it matters, never by running
a real gh from a probe. Behavior verified against gh and git themselves is in
the owner's harness, where it is installed.

## Layers

- `TaffarelJr.ProcessInvocation`: `Invoke-NativeCommand` streams the output
  lines and throws on a non-zero exit; `Invoke-NativeRead` never throws for the
  command's own failure and returns one result. `Get-Help` lists their
  parameters.
- One helper per tool is the only door to it: `Invoke-GitCommand`,
  `Invoke-GitHubCommand` (`-Tolerant` returns the result instead of throwing),
  `Invoke-GitHubApi` for `gh api`. Every function calls its tool through that
  helper, which hides credentials, writes the verbose line and builds the
  failure message. A new command-line tool gets the same. A GUI launcher (the
  VSCode module starts `code` detached) is the exception.

## Arguments

- An array, never a string and never `Invoke-Expression`:
  `& git @('-C', $path, 'status')`. A loose `-C` token binds as a PowerShell
  parameter silently.
- An operand the caller supplies (a ref, a name, a URL, a branch, a query) can
  start with `-` and become an option: `log --output=<file>` writes a file and
  `clone --upload-pack=<cmd>` runs a command. Reject a leading dash with
  `[ValidatePattern('^(?!-)')]`, and pass an operand after `--` only where the
  subcommand reads it there as a plain operand (a path, as in
  `git checkout -- <path>`). Where `--` means something else, guard by pattern
  only: `gh gist clone` and `gh repo fork` hand it to git, and in
  `git log -- main` it turns the branch into a path filter, so a revision stays
  before any `--` (`--end-of-options`, in git 2.24 and later, ends the options
  without that effect).
- A boolean or optional-value flag takes its value only as `--flag=value`:
  `--archived false` is `--archived` plus a stray `false`. A flag that always
  takes a value reads the next argument whatever it starts with, so `--owner -x`
  works; the `--flag=value` form is still the habit to keep, because it reads
  the same for every flag and cannot be split by a later `--`.
- A path is resolved against PowerShell's location first, and handed over
  absolute.

## Unattended

- Nothing may wait for a person. The environment, not an argument, decides, and
  `-Environment` sets it per call. A wrapped git gets `GIT_EDITOR=true`,
  `GIT_TERMINAL_PROMPT=0`, an empty `GIT_ASKPASS` and `GCM_INTERACTIVE=never`
  (`-c core.editor` loses to a caller's `GIT_EDITOR`). To blank a variable pass
  an empty string through `-Environment`: assigning `$env:NAME = ''` deletes
  it, so a probe built that way is not what a call sees.
- That does not cover SSH host-key or passphrase prompts, a tool that wants an
  editor (`gh gist edit --desc` alone), or a GUI dialog. Never run such a tool
  from a test or a probe; use the fake.
- Console state is not data: a captured run has no terminal, so colors, pagers
  and spinners are off. Set the encoding to UTF-8 and do not parse localized
  prose.

## Output and exit codes

- Parse stdout only, in a machine format: `--porcelain -z`, `--json` with named
  fields, `--format` with NUL or unit-separator delimiters. Keep stderr apart
  (`-SeparateStderr`) and show it in the failure message. Never merge the two
  into what you parse.
- A non-zero exit throws with a specific message: the activity, the command
  line (credentials hidden), the exit code or HTTP status, and the tool's own
  words. A missing tool throws "not found on PATH".
- A tolerant read is for a call whose failure is an answer (`Test-GitHubApi`:
  404 and 410 are `$false`, anything else throws). Read the stream the tool
  really uses. Some exit 1s mean "no" (`git diff --quiet`,
  `merge-base --is-ancestor`) and an exit above 1 means an error.
- An empty result is not a failure and a failure is not an empty result:
  `gh search --json` with no hits prints `[]` and exits 0.
- Parse with the repo's converters (`ConvertFrom-GitHubJson` re-cases to
  PascalCase and keeps data-keyed maps with `-KeepKeysOf`). A field list that
  needs a scope the token lacks fails every call: probe the default fields on a
  normal login.

## Secrets, versions, tests

- A secret goes on standard input or in the child environment, never in an
  argument, and any value that may be secret is `-Mask`ed (`module-secrets`).
- State the tool's minimum version in the README and let the tool's own
  "unknown flag" be the failure message.
- Test through the fake, add a contract test where the tool's own parsing is
  the oracle (`module-tests`).
