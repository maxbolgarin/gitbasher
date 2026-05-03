# Security Policy

## Supported versions

Only the latest minor version on `main` receives fixes. The single-file bundle published to npm and GitHub Releases is the supported surface; running `scripts/*.sh` directly from a checkout is supported for development but not for end users.

| Version | Supported |
|---------|-----------|
| latest `main` / latest npm | yes |
| older releases             | no  |

## Reporting a vulnerability

**Do not open a public issue for security reports.**

Please use GitHub's private vulnerability reporting:

1. Go to <https://github.com/maxbolgarin/gitbasher/security/advisories/new>
2. Describe the issue, the impact, and a reproduction (commands, environment, expected vs. actual).
3. If you have a fix, attach it as a patch — a draft PR can be linked privately to the advisory.

If GitHub advisories are unavailable, email **mxbolgarin@gmail.com** with subject `gitbasher security:` and the same details.

You can expect:

- Acknowledgement within **3 business days**.
- A status update within **10 business days** (triaged, severity, target fix window).
- A CVE / advisory and credit on disclosure, unless you ask to remain anonymous.

## Scope

In scope:

- Shell-injection, command-substitution, or argument-handling flaws in `scripts/*.sh` and the bundled `dist/gitb`.
- The install pipeline (`install.sh`, the curl/wget bootstrap, the npm package).
- The AI client paths in `scripts/ai.sh`, including credential handling, proxy validation, and request construction.
- The git hooks created by `gitb hook`.

Out of scope:

- Vulnerabilities that require an attacker to already have write access to your shell, repo, or git config.
- Anything in upstream `git`, `bash`, `curl`, `wget`, or third-party AI providers — please report those upstream.
- Documentation typos and non-security UX bugs (use a normal issue).

## Hardening notes for users

- Verify the SHA-256 of `dist/gitb` against the `.sha256` file published alongside each GitHub release.
- AI keys are stored via `git config` (per-repo by default). Prefer `--global` only on machines you trust.
- The install script supports `--https-only` enforcement on both `curl` and `wget` paths.
