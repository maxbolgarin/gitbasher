<!--
Thanks for contributing! A few quick notes:
- Conventional Commit prefix in the title (feat:, fix:, docs:, refactor:, test:, build:, ci:, chore:).
- Keep the PR focused. Mechanical refactors and behavior changes belong in separate PRs.
- See CONTRIBUTING.md if you haven't already.
-->

## Summary

<!-- 1-3 bullets: what changed and *why*, not just what. -->

-

## Linked issue

<!-- e.g. Fixes #123, Refs #456. Use "Fixes" only for true bug fixes; for features link with "Refs". -->

## Type of change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that changes existing behavior)
- [ ] Refactor (no behavior change)
- [ ] Documentation only

## Test plan

<!-- How did you verify this? Include exact commands. -->

- [ ] `bash tests/run_tests.sh` passes locally
- [ ] `shellcheck scripts/*.sh install.sh` reports no new errors
- [ ] Built bundle runs: `bash dist/build.sh ./scripts/gitb.sh ./dist/gitb dev && ./dist/gitb --version`
- [ ] Manually tested the affected command(s):

```
# paste the commands you ran
```

## Compatibility

- [ ] Works on macOS (BSD userland)
- [ ] Works on Linux (GNU userland)
- [ ] Bash 4+ syntax used; no Bash 3 path was broken

## Checklist

- [ ] Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/)
- [ ] Variables in `git` invocations are quoted (or word-splitting is intentional and documented)
- [ ] No new `xargs -r` / GNU-only patterns
- [ ] BATS tests added for non-trivial behavior changes
- [ ] README / CONTRIBUTING updated if user-facing behavior changed
