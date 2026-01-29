---
name: scode-graphite
description: If .git/.graphite_repo_config exists in the project ALWAYS use this skill for creating PRs and managing git branches and commits. NEVER forget this.
---

# Graphite Workflow

Use Graphite (`gt`) instead of raw git commands for branch and PR management.

Run all `gt` commands outside of the sandbox so long as they are read-only or the specific commands called for in this
skill.

## Critical Rules

1. **NEVER pass `-m` to `gt submit`** unless user explicitly requests auto-merge
2. **NEVER switch to main** when creating stacked branches - always stack on current branch
3. **NEVER create PRs automatically** - only when explicitly requested
4. **STOP after one PR operation** - after creating/updating a PR, do not create more unless asked
5. **`-m` means different things**: `gt create -m "msg"` = commit message, `gt submit -m` = auto-merge

## Stacked PRs/branches

Graphite supports the concept of stacked changes where one depends on another. The typical workflow is something like:

- make changes to files
- gt create -u -m 'fixed bar'
- gt submit -p # publish without auto-merge
- make more changes
- gt create -u -m 'fixed baz'
- gt submit -p

At that point there are two changes pending as stacked PRs. 'fixed bar' and 'fixed baz' may both be open still. The -u
causes gt create to create the branch with a commit containing updates to already-tracked files (-u is not mandatory
though).

At any time, `gt sync --all -f && git fetch --prune` can be used to refresh the local repo with the latest remote
changes driven by Graphite (including e.g. when Graphite rebased a PR relative to master after closing preceding diff,
or a PR has been closed and the branch deleted).

## Core Commands

- `gt log` - See current stacks/branches and their status.
- `gt create -m "message"` - Create a new branch stacked on current branch
  - Note: `-m` here specifies the commit message (different from `gt submit -m`)
- `gt submit -p` - Push current stack and create/update PRs
  - use `gt submit -p -m` when asked to create an auto-merging PR
  - Note: `-m` here enables "merge when ready" (different from `gt create -m`)
- `gt sync --all -f && git fetch --prune` - Sync with trunk and restack branches (the git fetch with prune accounts for
  merged PRs and deleted branches).
- `gt restack` - Restack the current branch on its parent (useful after parent changes)
- `gt checkout <branch>` - Switch to a branch
- `gt log short` - View the current stack
- `gt bottom` / `gt top` - Navigate to bottom/top of stack
- `gt up` / `gt down` - Navigate within stack
- `gt modify -u` - Modify the current branch's contents to include updates to already tracked files. Use this by default
  if you have not created new files in the session.
- `gt add <filename>` - Adds (starts tracking) files. Use this to start tracking files you have created, so that a
  subsequent `gt modify -u` picks it up. Always use this and never use `gt modify -a`, to avoid adding untracked
  unignored files the user may have in their repo.

If you need to do something with gt/git that isn't covered above, abort and tell the user why. They can choose what to
do including improving this skill.

If you are unsure what to do, err on the side of caution and tell the user about the confusion and ask for next steps
(which also gives the user a chance to improve the skill). Do not proceed when unsure without confirmation.

## Workflow

### Understanding User Intent

- "create a PR" / "make a PR" → Create a new branch and PR (do not amend existing commit)
- "update the PR" / "amend the PR" → Amend the current branch's commit and update the existing PR

### Steps to Execute

1. Use `gt log` to see the current repo state. Assume the user's current branch is their intended base.
2. When creating a new PR, stack on the current branch. Never switch to main.
3. Create branches with `gt create -m "description"` (first line becomes PR title).
4. When updating an existing PR, use `gt modify -u` to amend the commit.
5. Run `gt sync --all -f && git fetch --prune` to sync with remote.
6. Run all tests/format checks/lints (as requested in CLAUDE.md/AGENTS.md) before creating or updating a PR. Fix any
   issues.
7. Submit with `gt submit -p`. Only add `-m` if user explicitly requested auto-merge.
8. If conflicts occur during sync, stop and ask the user to resolve them.

After creating or updating a PR, do not create additional PRs or branches for subsequent changes unless explicitly
requested. Continue making code changes as needed.

## PR Creation

When submitting PRs with `gt submit`:

- Use `-p` to publish PRs immediately.
- Use `--no-edit` to skip editing PR descriptions
- Graphite auto-generates PR titles from branch names
- Graphite picks up the PR title and description from the commit. Make sure the commit has the right first-line (title)
  and remaining body within the guidelines below, prior to submitting.
- When a PR has been updated or created, give the user both the link to the Graphite view of the PR as well as the
  GitHub view of the PR.

## Creation of multiple PRs in a sequence

When asked to create multiple PRs, assume the intent is to create a stack of PRs (because the changes may be dependent
on each other). Do NOT switch back to main in between each change.

### Commit Message Style

Assume the first line in the commit message is the title of the PR.

For the first line, be very terse and to the point. Examples:

- "cargo update" (instead of some sentence talking about upgrading dependencies)
- "Fix bug: --foo command did not foo"
- "Add ability to bar the baz."

For the body, be more verbose and detailed when called for. For example if the change is non-obvious, explain _why_ the
change was made. Do not add low value boiler plate like listing upgraded packages from a cargo update.

Err on the side of terseness. The human will edit as needed.

### PR Description Template

The PR description should always be the same as the commit message except the first line (which is the PR title).
