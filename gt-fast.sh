#!/usr/bin/env bash
# Deterministic fast-path for common Graphite workflows.
# Handles happy-path new/update PRs, detached HEAD worktrees,
# and merged-parent recovery in a single invocation.
#
# Exit codes:
#   0 — success (stdout has gt submit output for PR link extraction)
#   1 — known error, recovery attempted but failed
#   2 — unknown/unexpected error, needs agent fallback
set -uo pipefail

usage() {
  echo "Usage:"
  echo "  gt-fast.sh new  <slug> <commit-message> [files-to-add...]"
  echo "  gt-fast.sh update [files-to-add...]"
  exit 2
}

# Run a gt command, capturing combined output. Returns the command's exit code.
# Sets GT_OUTPUT to the captured output.
run_gt() {
  GT_OUTPUT="$(gt "$@" 2>&1)" || return $?
  return 0
}

# Submit with single retry on merged-ancestor failures.
do_submit() {
  if run_gt submit -p --force --no-edit; then
    echo "$GT_OUTPUT"
    return 0
  fi

  local submit_exit=$?

  # Check for merged/closed ancestor pattern — the one case we retry.
  if echo "$GT_OUTPUT" | grep -qiE '(ancestor|stack).*(merged|closed)|has been merged'; then
    echo "gt-fast: submit failed with merged-ancestor warning, running sync..." >&2
    if ! run_gt sync --all -f; then
      echo "gt-fast: sync failed:" >&2
      echo "$GT_OUTPUT" >&2
      echo "$GT_OUTPUT"
      return 1
    fi

    # Single retry after sync.
    if run_gt submit -p --force --no-edit; then
      echo "$GT_OUTPUT"
      return 0
    fi

    echo "gt-fast: submit still failed after sync:" >&2
    echo "$GT_OUTPUT" >&2
    echo "$GT_OUTPUT"
    return 1
  fi

  # Unknown submit failure — let the agent handle it.
  echo "gt-fast: submit failed with unknown error:" >&2
  echo "$GT_OUTPUT" >&2
  echo "$GT_OUTPUT"
  return 2
}

# Add files if any were specified. Args: file paths.
add_files() {
  for f in "$@"; do
    if ! run_gt add "$f"; then
      echo "gt-fast: failed to add $f:" >&2
      echo "$GT_OUTPUT" >&2
      echo "$GT_OUTPUT"
      return 2
    fi
  done
}

# Ensure we're on a branch (handles detached HEAD in worktrees).
# For new PRs, uses the slug to name the anchor branch.
ensure_branch() {
  local slug="$1"
  local branch
  branch="$(git branch --show-current)"

  if [ -n "$branch" ]; then
    return 0
  fi

  # Detached HEAD — create an anchor branch.
  local anchor="automation/${slug}-$(date +%Y%m%d)"
  echo "gt-fast: detached HEAD, creating anchor branch $anchor" >&2
  if ! git switch -c "$anchor"; then
    echo "gt-fast: failed to create anchor branch" >&2
    return 2
  fi

  # Validate that main is a valid parent (left count must be 0).
  local counts
  counts="$(git rev-list --left-right --count main...HEAD 2>/dev/null)" || {
    echo "gt-fast: could not compare with main" >&2
    return 2
  }
  local left="${counts%%	*}"
  if [ "$left" != "0" ]; then
    echo "gt-fast: HEAD has diverged from main (left=$left), needs agent" >&2
    return 2
  fi

  if ! run_gt track -p main; then
    echo "gt-fast: failed to track anchor on main:" >&2
    echo "$GT_OUTPUT" >&2
    return 2
  fi

  return 0
}

# Handle gt create failure due to untracked branch.
handle_untracked_create() {
  local slug="$1"
  local message="$2"

  echo "gt-fast: current branch is untracked, attempting recovery..." >&2

  # Get gt's view of the stack to find the parent.
  local log_output
  log_output="$(gt log short 2>&1)" || true

  # Default parent assumption: main.
  local parent="main"

  # Validate parent relationship.
  local counts
  counts="$(git rev-list --left-right --count "${parent}...HEAD" 2>/dev/null)" || {
    echo "gt-fast: could not compare with $parent" >&2
    echo "$log_output"
    return 2
  }
  local left="${counts%%	*}"
  if [ "$left" != "0" ]; then
    echo "gt-fast: HEAD has diverged from $parent (left=$left), needs agent" >&2
    echo "$log_output"
    return 2
  fi

  # Track the current branch onto parent.
  if ! run_gt track -p "$parent"; then
    echo "gt-fast: failed to track on $parent:" >&2
    echo "$GT_OUTPUT"
    return 2
  fi

  # Retry create.
  if ! run_gt create "$slug" -u -m "$message"; then
    echo "gt-fast: create still failed after tracking:" >&2
    echo "$GT_OUTPUT"
    return 2
  fi

  return 0
}

cmd_new() {
  if [ $# -lt 2 ]; then
    usage
  fi

  local slug="$1"
  local message="$2"
  shift 2

  # Add files if specified.
  if [ $# -gt 0 ]; then
    add_files "$@" || return $?
  fi

  # Handle detached HEAD.
  ensure_branch "$slug" || return $?

  # Create the branch.
  if ! run_gt create "$slug" -u -m "$message"; then
    # Check if it's an untracked branch error.
    if echo "$GT_OUTPUT" | grep -qi "untracked branch"; then
      handle_untracked_create "$slug" "$message" || return $?
    else
      echo "gt-fast: create failed:" >&2
      echo "$GT_OUTPUT" >&2
      echo "$GT_OUTPUT"
      return 2
    fi
  fi

  do_submit
}

cmd_update() {
  # Add files if specified.
  if [ $# -gt 0 ]; then
    add_files "$@" || return $?
  fi

  if ! run_gt modify -u; then
    echo "gt-fast: modify failed:" >&2
    echo "$GT_OUTPUT" >&2
    echo "$GT_OUTPUT"
    return 2
  fi

  do_submit
}

# Main dispatch.
if [ $# -lt 1 ]; then
  usage
fi

case "$1" in
  new)
    shift
    cmd_new "$@"
    ;;
  update)
    shift
    cmd_update "$@"
    ;;
  *)
    usage
    ;;
esac
