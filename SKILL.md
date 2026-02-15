---
name: scode-graphite
description: If .git/.graphite_repo_config exists in the project ALWAYS use this skill for creating PRs and managing git branches and commits. NEVER forget this.
---

# Graphite Workflow

Use Graphite (`gt`) instead of raw git commands for branch and PR management. Run all `gt` commands outside of the
sandbox.

## Critical Rules

1. **NEVER pass `-m` to `gt submit`** unless user explicitly requests auto-merge. Note: `-m` means different things in
   different commands — `gt create -m "msg"` sets the commit message, `gt submit -m` enables auto-merge.
2. **NEVER switch to main** when creating stacked branches — always stack on current branch.
3. **NEVER create PRs automatically** — only when explicitly requested.
4. **STOP after one PR operation** — after creating/updating a PR, do not create more unless asked.

## Create a New PR

1. `gt add <files>` — only if you created new files
2. `gt create -u -m "commit message"` — creates a new branch stacked on the current branch
3. `gt submit -p --force --no-edit` — publishes the PR

## Update an Existing PR

1. `gt add <files>` — only if you created new files
2. `gt modify -u` — amends the current branch's commit with tracked file changes
3. `gt submit -p --force --no-edit` — updates the PR

## After Submitting

After `gt submit` completes, your **final output** must be the PR links in this exact format (nothing else after them):

```
GitHub:   https://github.com/{owner}/{repo}/pull/{number}
Graphite: https://app.graphite.com/github/pr/{owner}/{repo}/{number}
```

Extract the PR number from the `gt submit` output. Derive the owner and repo from the git remote origin URL. Always
print both links as the very last thing you output. Do not create additional PRs or branches unless explicitly asked.

## Understanding User Intent

- "create a PR" / "make a PR" → use the **Create** workflow above (new branch + PR)
- "update the PR" / "amend the PR" → use the **Update** workflow above (amend existing commit)
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
- `gt sync --all -f && git fetch --prune` — sync with trunk and restack branches. If conflicts occur, stop and ask the
  user to resolve them.
- `gt restack` — restack the current branch on its parent
- `gt checkout <branch>` — switch to a branch
- `gt bottom` / `gt top` / `gt up` / `gt down` — navigate within a stack
- `gt add <filename>` — start tracking a file (prefer this over `gt modify -a` to avoid adding untracked files)
- `gt modify -u` — amend the current branch's commit with updates to tracked files
- `gt create -m "message"` — create a new branch stacked on current branch
- `gt submit -p --force --no-edit` — push and create/update PRs (add `-m` only if user requests auto-merge, `--draft`
  for draft PRs)

If you need to do something with gt/git that isn't covered above, stop and tell the user why.

## Error Handling

- **Conflicts during sync/restack**: Stop and ask the user to resolve them.
- **Authentication or permission errors**: Tell the user — these require manual intervention (e.g., `gt auth`).
- **State errors** (e.g., "not on a Graphite stack"): Run `gt log` to diagnose, then tell the user.
- **Command hangs**: Likely waiting for interactive input — cancel it and tell the user.
