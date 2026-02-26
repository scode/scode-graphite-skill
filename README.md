# scode-graphite-skill

An opinionated Claude skill for using graphite with git repos and PRs.

This is intentionally encoding personal preferences and is meant to fit my own workflow. I make no claims that this is
generally useful as a generic graphite skill.

It is designed to be used whenever the project you are working contains this file:

```
.git/.graphite_repo_config
```

Which should indicate that `gt init` has been run, therefore indicating the user's desire to use Graphite with the repo.

# Caveats

Particularly "opinionated" behaviors that may be problematic (may not be a complete list) depending on whether your
workflow matches mine:

- It assumes all-in on Graphite and no lower level twiddling of refs or commits out of band using git. `--force` and
  `--no-edit` flags are used on submit, remote branches are automatically pruned.
- The skill does have instructions to enable auto-merging on PRs when explicitly requested. Be aware given that it's
  possible for the agent to incorrectly do so even w/o the explicit request, potentially causing unintended and
  unreviewed code to be merged.
- Draft PR support is available via `--draft` flag but must be explicitly requested.
- All `gt` commands require `dangerouslyDisableSandbox: true` on the Bash tool call because `gt` needs write access to
  `.git/` and network access to GitHub/Graphite APIs, both of which the sandbox blocks.
