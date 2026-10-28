# Repository Git workflow

Read the branch and commit conventions in `README.md` before changing Git history.
Shared changes belong on `main` with conventional commit messages. Each machine's
`local` branch holds machine-specific or intentionally unpublished commits using
`local(scope): summary`; never push that branch or merge it wholesale into `main`.
Prepare shared changes in a separate worktree, preserve unrelated dirty work and
submodule changes, and leave published history intact.
