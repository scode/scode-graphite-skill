# scode-graphite-skill

An opinionated Claude skill for using graphite with git repos and PRs.

This is intentionally encoding personal preferences and is meant to fit my own
workflow. I make no claims that this is generally useful as a generic graphite
skill.

It is designed to be used whenever the project you are working contains this
file:

```
.git/.graphite_repo_config
```

Which should indicate that `gt init` has been run, therefor indicating the user's
desire to use Graphite with the repo.
