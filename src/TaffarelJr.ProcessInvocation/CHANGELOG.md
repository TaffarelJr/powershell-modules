# Changelog

## 0.1.0

Initial release: `Invoke-NativeCommand` (captures output, throws with
detail on failure), `Invoke-NativeRead` (never throws, reports success
and output, resets `$LASTEXITCODE`), and `Assert-ExitCode` (a plain
throw-if-nonzero check for a command whose output already streamed to
the console).
