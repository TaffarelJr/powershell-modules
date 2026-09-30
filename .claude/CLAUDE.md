@../AGENTS.md

# powershell-modules

Rules for every session in this repository. Before a task, invoke the skill the
table names for it: its description says when it applies, and the rules that
must never be missed are here.

## Always

- Never print a secret. List environment variable names, never values; do not
  run `gh auth token`, read credential files, or dump git configuration, remote
  URLs or process command lines unfiltered. Use sentinels, never a real
  credential. If one slips out, stop and tell the owner at once.
- Run commands with absolute paths, scripts in files and long runs in the
  background, and never a real tool, GUI, SSH session or installer from a
  probe.
- Run only the tests of the module you changed, plus the modules that require
  it when it is a shared one. Never the whole suite.
- Open every pull request as a draft. Only the owner marks one ready for review
  and merges it; you never merge one or push to `main`. Push a branch only for a
  pull request the owner asked for. `repo-workflow` says how commits and pull
  requests are shaped; there are no version bumps until real Gallery
  publishing starts.
- Address every comment on a pull request, from a person or a bot: fix what
  applies, reply concisely, resolve the thread once that is appropriate, and
  ask when a comment is not clear.
- The repository is public: no account logins, tokens, machine names or local
  paths in any file, issue or commit. The project's own name and URLs are fine.
- Match the surrounding code, and probe a claim before you write it down.

## Which skill

Skills marked * are the owner's user-level skills; where they are not
installed, `AGENTS.md` carries the rules that matter here.

| Task | Read |
| :--- | :--- |
| Running any command, test run or git operation | `running-powershell`* |
| Anything that may touch a token, password or key in a session | `handling-secrets`* |
| Module code or a test that handles a secret | `module-secrets` |
| Writing or changing PowerShell in any file, tests included | `powershell-style`*, `powershell-pitfalls`* |
| Writing or changing an exported function | also `public-function-contract` |
| Writing, running or reviewing tests | `module-tests` |
| Adding a module, or writing a manifest or README | `module-structure` |
| Preparing or publishing a module for the Gallery | `publishing-modules` |
| Writing or changing a function that runs git, gh or another native tool | `wrapping-native-tools` |
| Reviewing a module | `module-review` |
| Briefing or checking a sub-agent | `delegating-to-agents`* |
| Committing, issues, finishing a change | `repo-workflow` |
| Pull requests, stacks, folding fixes into earlier commits | `stacked-pull-requests`*, `repo-workflow` |
| Answering comments on a pull request | `review-feedback`* |
