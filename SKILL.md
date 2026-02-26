---
name: scode-graphite
description: If .git/.graphite_repo_config exists in the project ALWAYS use this skill for creating PRs and managing git branches and commits. NEVER forget this.
---

# Graphite Workflow

Use Graphite (`gt`) instead of raw git commands for branch and PR management. Run `gt` commands directly; only request
escalation when required by environment policy.

## Sandbox

**ALL `gt` commands MUST be run with `dangerouslyDisableSandbox: true`.** The `gt` CLI writes to `.git/` (refs, objects,
config, hooks, HEAD) and makes network requests to GitHub and Graphite APIs — the sandbox blocks both. Set
`dangerouslyDisableSandbox: true` on every Bash tool call that runs a `gt` command. This applies to agents and subagents
equally.

## Critical Rules

1. **NEVER pass `-m` to `gt submit`** unless user explicitly requests auto-merge. Note: `-m` means different things in
   different commands — `gt create -m "msg"` sets the commit message, `gt submit -m` enables auto-merge.
2. **NEVER run `gt sync --all -f` between a new local commit and the first `gt submit` attempt on that branch.**
3. **Do not run proactive sync preflights** before `gt create` or `gt submit`.
4. **ALWAYS provide an explicit branch name in `gt create`** (for example `<short-slug>`) to avoid later branch fixes.
5. **NEVER switch to main** when creating stacked branches — always stack on current branch.
6. **NEVER create or update PRs unless the user explicitly asks in that message.** A prior request to create or update a
   PR does NOT authorize future creates or updates. Each `gt create`, `gt modify`, and `gt submit` requires a fresh
   explicit request. If the user says "update the PR" and you do, then the user asks for more code changes, make only
   the code changes — do NOT update the PR again until explicitly asked again.
7. **NO exploratory commands by default**: do not run `gt ... --help`, extra diagnostics, or alternate command
   experiments unless a command fails with an unknown flag or unknown state.

## Create a New PR (Fast Path)

1. `gt add <files>` — only if you created new files
2. `gt create <short-slug> -u -m "commit message"` — creates a new branch stacked on the current branch
3. `gt submit -p --force --no-edit` — publishes the PR

## Update an Existing PR

1. `gt add <files>` — only if you created new files
2. `gt modify -u` — amends the current branch's commit with tracked file changes
3. `gt submit -p --force --no-edit` — updates the PR

## `gt submit` Retry Policy

If `gt submit` fails specifically because lower PRs in the stack were merged/closed (ancestor/stack-merged warning):

1. Run `gt sync --all -f` once.
2. Retry `gt submit -p --force --no-edit` once.
3. If it fails again, stop and report the error. Do not loop or run workaround commands.
4. For any other `gt submit` failure, do not run `gt sync`; stop and report the error.

## After Submitting

After `gt submit` completes, your **final output** must be the PR links in this exact format (nothing else after them):

```
GitHub:   https://github.com/{owner}/{repo}/pull/{number}
Graphite: https://app.graphite.com/github/pr/{owner}/{repo}/{number}
```

Extract the PR number from the `gt submit` output. Derive the owner and repo from the git remote origin URL. Always
print both links as the very last thing you output. Do not create additional PRs or branches unless explicitly asked.

## Understanding User Intent

- "create a PR" / "make a PR" → **always** use the **Create** workflow (new branch + PR), even if the current branch
  already has a PR. "Make/create" always means a new PR stacked on the current branch, never an update.
- "update the PR" / "amend the PR" → use the **Update** workflow above (amend existing commit on the current branch)
- Multiple PRs in sequence → create a stack (do NOT switch back to main between each)

If you are unsure what to do, stop and ask the user rather than proceeding.

## Commit Message Style

The first line of the commit message becomes the PR title. Keep it very terse:

- "cargo update"
- "Fix bug: --foo command did not foo"
- "Add ability to bar the baz."

For the body, explain _why_ the change was made when the reasoning is non-obvious. Err on the side of terseness.

The PR description is the commit message body (everything after the first line).

## Reference Commands

These are available when needed but are not mandatory steps:

- `gt log` / `gt log short` — view current stacks/branches and their status
- `gt sync --all -f` — reconcile/restack branch state. Do not run this proactively before a first submit attempt after a
  new commit; use it only after merged/closed ancestor submit failures or when explicitly requested.
- `gt restack` — restack the current branch on its parent
- `gt checkout <branch>` — switch to a branch
- `gt bottom` / `gt top` / `gt up` / `gt down` — navigate within a stack
- `gt add <filename>` — start tracking a file (prefer this over `gt modify -a` to avoid adding untracked files)
- `gt modify -u` — amend the current branch's commit with updates to tracked files
- `gt create <short-slug> -m "message"` — create a new branch stacked on current branch
- `gt submit -p --force --no-edit` — push and create/update PRs (add `-m` only if user requests auto-merge, `--draft`
  for draft PRs)

If you need to do something with gt/git that isn't covered above, stop and tell the user why.

## Error Handling

- **Merged/closed ancestor warnings on `gt submit`**: Follow the retry policy above (single sync + single retry).
- **Any other `gt submit` failure**: Stop immediately, report the error, and do not run `gt sync`.
- **Conflicts during sync/restack**: Stop and ask the user to resolve them.
- **Authentication, permission, conflict, or hook errors**: Stop immediately, report the error, and ask the user. Do not
  run unrelated commands.
- **State errors** (e.g., "not on a Graphite stack"): Run `gt log` once to diagnose, then stop and tell the user.
- **Command hangs**: Likely waiting for interactive input — cancel it and tell the user.
