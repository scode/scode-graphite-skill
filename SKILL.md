---
name: scode-graphite
description: If .git/.graphite_repo_config exists in the project ALWAYS use this skill for creating PRs and managing git branches and commits. NEVER forget this.
---

# Graphite Workflow

Use Graphite (`gt`) instead of raw git commands for branch and PR management.

## Sandbox

**ALL `gt` commands and `gt-fast.sh` MUST be run with `dangerouslyDisableSandbox: true`.** The `gt` CLI writes to
`.git/` (refs, objects, config, hooks, HEAD) and makes network requests to GitHub and Graphite APIs — the sandbox blocks
both. This applies to agents and subagents equally.

## Critical Rules

1. **NEVER pass `-m` to `gt submit`** unless user explicitly requests auto-merge. Note: `-m` means different things in
   different commands — `gt create -m "msg"` sets the commit message, `gt submit -m` enables auto-merge.
2. **NEVER run `gt sync --all -f` between a new local commit and the first `gt submit` attempt on that branch.**
3. **Do not run proactive sync preflights** before `gt create` or `gt submit`.
4. **ALWAYS provide an explicit branch name in `gt create`** (for example `<short-slug>`) to avoid later branch fixes.
5. **NEVER switch to main** when creating stacked branches — always stack on current branch.
6. **NEVER create or update PRs unless the user explicitly asks in that message.** A prior request to create or update a
   PR does NOT authorize future creates or updates. Each PR operation requires a fresh explicit request.
7. **NO exploratory commands by default**: do not run `gt ... --help`, extra diagnostics, or alternate command
   experiments unless a command fails with an unknown flag or unknown state.

## Fast Path (preferred)

For new and update PR operations, use the `gt-fast.sh` script located in the same directory as this SKILL.md file. It
handles the happy path, detached HEAD worktrees, merged-parent recovery, and untracked-branch recovery deterministically
in a single invocation.

### Usage

Run with `dangerouslyDisableSandbox: true`.

**New PR:**

```bash
/path/to/gt-fast.sh new <short-slug> "<commit message>" [files-to-add...]
```

Only pass files-to-add for newly created files. The commit message first line becomes the PR title.

**Update PR:**

```bash
/path/to/gt-fast.sh update [files-to-add...]
```

### Handle the result

- **Exit 0** — success. Extract the PR number from the output. Print the PR links (see "After Submitting" below) and
  stop.
- **Exit 1** — known error, recovery was attempted but failed. Read the output, then follow the "Agent Fallback"
  recovery procedures below.
- **Exit 2** — unknown error. Read the output, then follow the "Agent Fallback" recovery procedures below.

## After Submitting

After a successful submit (whether via `gt-fast.sh` or manual commands), your **final output** must be the PR links in
this exact format (nothing else after them):

```
GitHub:   https://github.com/{owner}/{repo}/pull/{number}
Graphite: https://app.graphite.com/github/pr/{owner}/{repo}/{number}
```

Extract the PR number from the submit output. Derive the owner and repo from the git remote origin URL. Always print
both links as the very last thing you output. Do not create additional PRs or branches unless explicitly asked.

## Understanding User Intent

- "create a PR" / "make a PR" → **always** use the **Create** workflow (new branch + PR), even if the current branch
  already has a PR. "Make/create" always means a new PR stacked on the current branch, never an update.
- "update the PR" / "amend the PR" → use the **Update** workflow (amend existing commit on the current branch)
- Multiple PRs in sequence → create a stack (do NOT switch back to main between each)

If you are unsure what to do, stop and ask the user rather than proceeding.

## Commit Message Style

The first line of the commit message becomes the PR title. Keep it very terse:

- "cargo update"
- "Fix bug: --foo command did not foo"
- "Add ability to bar the baz."

For the body, explain _why_ the change was made when the reasoning is non-obvious. Err on the side of terseness.

The PR description is the commit message body (everything after the first line).

---

# Agent Fallback

Use this section only when `gt-fast.sh` is unavailable or exits non-zero. Run `gt` commands one at a time with
`dangerouslyDisableSandbox: true`, following the procedures below.

## Create a New PR (Manual)

1. `gt add <files>` — only if you created new files
2. `gt create <short-slug> -u -m "commit message"` — creates a new branch stacked on the current branch
3. `gt submit -p --force --no-edit` — publishes the PR

## Update an Existing PR (Manual)

1. `gt add <files>` — only if you created new files
2. `gt modify -u` — amends the current branch's commit with tracked file changes
3. `gt submit -p --force --no-edit` — updates the PR

## Recovery: Detached HEAD (Codex Automation Worktree)

Codex automation worktrees often start detached at a commit that already exists on an integration branch. Use this
deterministic flow so PR creation does not require trial-and-error:

1. Check `git branch --show-current`.
2. If non-empty, skip this section.
3. If empty, create a local anchor branch at the current commit: `git switch -c automation/<slug>-<yyyymmdd>`.
4. Pick parent `main` by default and validate with: `git rev-list --left-right --count main...HEAD`. If the left count
   is `0`, keep parent `main` (both `0 0` and `0 N` are valid).
5. If the left count is non-zero, run `gt log short` once, pick one obvious parent from the tracked stack, and validate
   it with the same `git rev-list` check. If no obvious parent has left count `0`, stop and ask the user.
6. Track the anchor branch onto the parent: `gt track -p <parent>`.
7. Continue with the normal create flow (`gt create ...`, then `gt submit ...`).

## Recovery: Untracked Branch

If `gt create` fails with "untracked branch":

1. Run `gt log short` once to see the tracked stack.
2. Identify the obvious parent branch.
3. Validate branch relationship with `git rev-list --left-right --count <parent>...HEAD`:
   - `0 0`: placeholder branch at parent tip; safe to continue.
   - `0 N`: branch is ahead of parent but not diverged; safe to continue.
   - non-zero left count: diverged/ambiguous parent; stop and ask the user.
4. Run `gt track -p <parent>` on the existing branch.
5. Retry `gt create <short-slug> -u -m "commit message"`.
6. If the new Graphite branch sits on top of an empty placeholder branch, run `gt track -p <parent>` again on the new
   branch before `gt submit`. This reparents the PR branch directly onto the real parent so the empty placeholder branch
   does not block submission.
7. Run `gt submit -p --force --no-edit`.

Do not use `gt sync` for this recovery. This is a branch-parenting problem, not a sync problem.

## `gt submit` Retry Policy

If `gt submit` fails specifically because lower PRs in the stack were merged/closed (ancestor/stack-merged warning):

1. Run `gt sync --all -f` once.
2. Retry `gt submit -p --force --no-edit` once.
3. If it fails again, stop and report the error. Do not loop or run workaround commands.
4. For any other `gt submit` failure, do not run `gt sync`; stop and report the error.

## Reference Commands

These are available when needed but are not mandatory steps:

- `gt log` / `gt log short` — view current stacks/branches and their status
- `gt sync --all -f` — reconcile/restack branch state (only after merged/closed ancestor submit failures or when
  explicitly requested)
- `gt restack` — restack the current branch on its parent
- `gt track -p <parent>` — attach the current branch to an existing parent branch, or reparent it
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
- **`gt submit` says a lower branch introduces no changes / empty PR and nothing was submitted**: this is usually an
  intermediate placeholder branch. Reparent the current branch with `gt track -p <parent>` (same parent used during
  `gt create`) and retry `gt submit -p --force --no-edit` once.
- **Any other `gt submit` failure**: Stop immediately, report the error, and do not run `gt sync`.
- **Conflicts during sync/restack**: Stop and ask the user to resolve them.
- **Authentication, permission, conflict, or hook errors**: Stop immediately, report the error, and ask the user. Do not
  run unrelated commands.
- **`gt create` says the current branch is untracked**: Treat this as the untracked-branch case above.
- **State errors** (e.g., "not on a Graphite stack"): Run `gt log` once to diagnose, then stop and tell the user.
- **Command hangs**: Likely waiting for interactive input — cancel it and tell the user.
