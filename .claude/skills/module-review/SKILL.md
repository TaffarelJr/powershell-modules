---
name: module-review
description: >-
  Adversarial method for reviewing a module or change for defects: list every
  claim, probe each one, break the code on purpose, and prefer mechanical
  checks to reading. Use when reviewing a module, running a review round, or
  fixing a bug found in review.
when_to_use: >-
  Trigger phrases: review this module, adversarial review, find bugs, audit,
  mutation test, review round.
---

# Reviewing a module

Assume the code is wrong and prove it. Reading finds the obvious; running finds
the rest. The GitHub issues titled "Adversarial review" are the checklists: one
module at a time, in dependency order.

## Method

1. Read the source, tests, README and manifest, and list every claim they make:
   help text, README sentences, comments, test names.
2. Probe each claim with a throwaway script and odd inputs: fakes, throwaway
   repositories, `<tool> --help` and the tool's source, never the user's data
   or a real gh.
3. Break the code on purpose (invert a condition, delete a guard, change an
   operator) in a scratch copy of the repository, never the working tree, and
   run the module's tests there. A mutation that survives is a missing test, or
   an equivalent change to dismiss with a reason. Run each file with a timeout
   and kill its process tree: a mutation can make git wait for an editor
   forever.
4. Rank the findings. Every one is fixed, or dismissed deliberately with a
   reason: none stays silently open. A fix starts as a failing test.
5. Commit the fix as `repo-workflow` says (folded into the commit that
   introduced it while the pull request is open), re-run the module's tests,
   tick the issue and post a status comment.

## What to look for

Check the code against the rules in `public-function-contract`,
`wrapping-native-tools`, `module-secrets` and `module-tests`. Beyond them:

- Defaults that act unasked: a prompt defaulting to yes, "no paths given"
  meaning "everything", a switch that is off meaning on.
- Every behavioral sentence in a README or help is a claim to probe; examples
  and lists go stale first.
- Consistency across modules: parameter names and aliases, wording, defaults,
  error shapes.
- Tests that pass for the wrong reason (`module-tests`, Traps), such as a
  vacuous assertion (`-is [array]` for zero or one item).
- An option that offers what the tool never does.

## Mechanical checks beat reading

- After a mechanical change across many files, compare the old and new bodies
  token by token (parse both, drop the wrapper, compare the token text): it
  proves "nothing else changed" and lists what did.
- The public-surface test, the analyzer file by file, `git status --short` and
  `git diff --stat` for strays, and a scan for token-shaped literals.
- Probe a claim, then write the claim. A README sentence you did not run is a
  guess.

## Keeping the skills true

A rule in a skill that the code contradicts is a defect in one of them: probe,
then fix whichever is wrong. To test a skill, have a fresh agent build a small
module from the skills alone in a scratch copy of the repository; every place it
stalls or guesses is a gap.
