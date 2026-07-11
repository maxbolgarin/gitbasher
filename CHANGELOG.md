# Changelog

All notable changes to gitbasher are generated automatically by [semantic-release](https://github.com/semantic-release/semantic-release) from [Conventional Commits](https://www.conventionalcommits.org/) on `main`. The project follows [Semantic Versioning](https://semver.org/).

## [5.2.1](https://github.com/maxbolgarin/gitbasher/compare/v5.2.0...v5.2.1) (2026-07-11)

### 🐛 Bug Fixes

* **commit:** gate AI split by scope count and stop discarding near-complete groupings ([90becec](https://github.com/maxbolgarin/gitbasher/commit/90becec0f49a7a3e57e57e11a71b6909884ab337))

## [5.2.0](https://github.com/maxbolgarin/gitbasher/compare/v5.1.0...v5.2.0) (2026-07-07)

### 🚀 Features

* **ai:** one model per provider with live pickers, reasoning control, and setup safety checks ([a9c6935](https://github.com/maxbolgarin/gitbasher/commit/a9c6935297e84b777c8428203dae7003ef93aa38))

### 🐛 Bug Fixes

* **ai:** extract bare scope from full type(scope) prefixes ([18da7e4](https://github.com/maxbolgarin/gitbasher/commit/18da7e4648a0dda2aec2453305bcdf95110feea7))
* **config:** move values to global scope instead of shadowing them locally ([648ef37](https://github.com/maxbolgarin/gitbasher/commit/648ef3735dfd6c1aa248369d51bdb57ad42c3353))

### 📚 Documentation

* describe per-provider AI models, live model menus, and reasoning behavior ([dab3cef](https://github.com/maxbolgarin/gitbasher/commit/dab3cef479d619e59e69b6d4f3a75514e7b6d00d))

### 🚨 Tests

* keep [@test](https://github.com/test) descriptions ASCII for bats under bash 3.2 ([1e3fb50](https://github.com/maxbolgarin/gitbasher/commit/1e3fb50071d927b8475178ffdae68afcf7ebc19a))

## [5.1.0](https://github.com/maxbolgarin/gitbasher/compare/v5.0.1...v5.1.0) (2026-07-03)

### 🚀 Features

* **ai:** add local Claude Code CLI (claude -p) provider ([bc3e663](https://github.com/maxbolgarin/gitbasher/commit/bc3e66341903c1ed93f7191dc6ee6840173bf13b))
* **config:** keep or replace an existing AI key with one keystroke ([95ba4a6](https://github.com/maxbolgarin/gitbasher/commit/95ba4a649d8ab9288cb5e73760076effce2b8ddc))
* **commit:** offer manual fallback when AI message generation fails ([39ac769](https://github.com/maxbolgarin/gitbasher/commit/39ac7697d6ca5063c09aa8b661c1263581e2adc3))
* **config:** turn gitb cfg ai into a provider/key/model setup wizard ([22795fe](https://github.com/maxbolgarin/gitbasher/commit/22795fe90980b2a6e848529eff6aa3a2939f89f5))

### 🐛 Bug Fixes

* **ai:** move OpenRouter default models to the current generations ([82a26a0](https://github.com/maxbolgarin/gitbasher/commit/82a26a0797aafe11e71ff4e8e737830fe567b4c2))
* **ai:** pick default models by measured latency, speed first ([29d48b8](https://github.com/maxbolgarin/gitbasher/commit/29d48b8d21ac04bd639dee723770a2bcdae38328))

### 📚 Documentation

* **site:** mention the claude CLI provider and the cfg ai wizard ([23c9087](https://github.com/maxbolgarin/gitbasher/commit/23c9087783b805f8ed651735304305a1163a47c3))
* refresh test count, document the AI fallback, mention claude on the site FAQ ([af6527d](https://github.com/maxbolgarin/gitbasher/commit/af6527d08aceb20bf75ab7a3c0fe745fe1cef16f))

### 💎 Styles

* capitalize the Enter default in every y/n prompt ([37349a0](https://github.com/maxbolgarin/gitbasher/commit/37349a0d166b235b9b7c33dc2767e5b2093ec004))

## [5.0.1](https://github.com/maxbolgarin/gitbasher/compare/v5.0.0...v5.0.1) (2026-07-03)

### 🐛 Bug Fixes

* **base:** render embedded colors in the main help instead of literal escapes ([95ffbc6](https://github.com/maxbolgarin/gitbasher/commit/95ffbc62fab836ea97f9de2bd3c542b5ae659f9a))
* **push:** widen the transfer quiet window so ordinary pushes stay silent ([fcccb6b](https://github.com/maxbolgarin/gitbasher/commit/fcccb6b8cd941c9e721d9c392d45f351ca4aa924))

### 🛠 Build System

* **deps:** pin conventional-changelog-conventionalcommits to v8 ([b9163f8](https://github.com/maxbolgarin/gitbasher/commit/b9163f8c859e1cb35bbb08a57ce69a374005d3ea))

## [5.0.0](https://github.com/maxbolgarin/gitbasher/compare/v4.1.0...v5.0.0) (2026-07-03)

### ⚠ BREAKING CHANGES

* unknown commands and unknown modes now exit non-zero
(previously 0). Destructive prompts (force-delete, drop, remove, undo,
reset, delete-all, accept-theirs/ours, squash apply) require an
explicit "y": Enter declines and closed stdin aborts instead of
auto-confirming. Piped or redirected `gitb log` prints the plain log
instead of interactive browser pages, and all output is uncolored when
stdout is not a terminal (NO_COLOR is honored). jq is required for AI
features. Path inputs containing control characters are rejected
instead of silently rewritten, and `../` in worktree/clone paths is
honored instead of stripped.

### 🚀 Features

* **log:** add ai mode summarizing commit ranges ([469d7c1](https://github.com/maxbolgarin/gitbasher/commit/469d7c16274e31bab9959c3802f12847871a41aa))
* **completion:** add all, dump and ai modes to log completion ([e7435e3](https://github.com/maxbolgarin/gitbasher/commit/e7435e3b37b656ea87b22afff4c6fa5871192ec8))
* **log:** add commit list renderer with decorations, truncation and unpushed markers ([783cb8e](https://github.com/maxbolgarin/gitbasher/commit/783cb8e15291669a0d41f01b13092f9978e9501d))
* add diff command and AI-powered feature grouping for commits ([c725be6](https://github.com/maxbolgarin/gitbasher/commit/c725be642515e58045e38896535fa7a979a0c8e3))
* **ai:** add ollama host configuration, model id validation, and provider smoke check functionality ([b7c4e20](https://github.com/maxbolgarin/gitbasher/commit/b7c4e2085268eda01aa8cbc7a3d6c795ef2b8c79))
* **merge:** add push modifier to merge command for automatic post-merge pushing ([ceb38c6](https://github.com/maxbolgarin/gitbasher/commit/ceb38c6fd798c5335598fdf7f2cbba3cdf7ef9d1))
* **rebase:** add push modifier to rebase command for post-rebase force-pushing ([1a4fa38](https://github.com/maxbolgarin/gitbasher/commit/1a4fa38662806fa6b936e78b248db031799f1a11))
* **completion:** add push options to merge and rebase commands ([37d6df5](https://github.com/maxbolgarin/gitbasher/commit/37d6df5d33f587513d30037e9ffcab86c0f9e38c))
* **fetch:** add top-level fetch command with prune mode ([7f981ef](https://github.com/maxbolgarin/gitbasher/commit/7f981ef77ca5a9cc9bfe7b567b8ed60972130139))
* **log:** make an interactive commit browser the default log view ([c033bac](https://github.com/maxbolgarin/gitbasher/commit/c033bac2c29d2994228eb60997136fc87000782b))
* **branch:** offer to push new branches to the remote ([e74cfdb](https://github.com/maxbolgarin/gitbasher/commit/e74cfdb86c952b1cea66ca395601227ae62552e8))
* **commit:** order split commits by scope dependency ([96f7518](https://github.com/maxbolgarin/gitbasher/commit/96f7518d9af2a9451fd11cb11be8db655f78fe88))
* reliability overhaul - safe prompts, honest exit codes, true bash 3.2 support ([645970f](https://github.com/maxbolgarin/gitbasher/commit/645970fdc75bb7a8a6d917d1653c0a977ad2572e))
* **status:** show upstream, stash, in-progress state and grouped changes ([e3f23b3](https://github.com/maxbolgarin/gitbasher/commit/e3f23b33e73b051db7eaaf647870e363a5d12dd9))
* **push:** stream live progress and warn before large pushes ([a1f3f33](https://github.com/maxbolgarin/gitbasher/commit/a1f3f33a0074badd07633a1ed61338bdc31724e9))
* **log:** support smart positional arguments (count, path, ref, message search) ([be9f1ee](https://github.com/maxbolgarin/gitbasher/commit/be9f1eed3e3efa64bdd60c6b446b1fdc476e75fc))

### 🐛 Bug Fixes

* **common:** assemble multi-byte keys correctly under bash 3.2 ([0b65802](https://github.com/maxbolgarin/gitbasher/commit/0b65802130da7335b98fb4c8752c570564827472))
* **branch:** exact-name list filtering and plumbing-based cleanup parsers ([9c6b2b0](https://github.com/maxbolgarin/gitbasher/commit/9c6b2b05f039f9b4d6d8a3f17867805fe754e361))
* **common:** exit non-zero on error paths instead of status 0 ([f2b6330](https://github.com/maxbolgarin/gitbasher/commit/f2b6330db148eacce6b5ecf4c9bdc84c32704031))
* **install): working --help and fish advice; test(infra:** honest harness ([4f1bbe8](https://github.com/maxbolgarin/gitbasher/commit/4f1bbe8acc64f939d7d32c845677a0b09aeb695e))
* **worktree:** honest path handling and a usable path mode ([7a9ea79](https://github.com/maxbolgarin/gitbasher/commit/7a9ea7920f9caa1ff4a2f6b0c1bdea1c60d5662b))
* **tag:** honest remote deletes, robust delete-all, clean tag drafts ([98f4ec0](https://github.com/maxbolgarin/gitbasher/commit/98f4ec01041b0fa5ee96ef04bc520d4d79af5ae0))
* **stash): pathspec-based select; fix(undo): honest guards; fix(cherry:** live state detection ([52d27fb](https://github.com/maxbolgarin/gitbasher/commit/52d27fbf1e08703d51b5df16137145ec9c9ad4ca))
* **init:** make environment probes locale-proof and respect user config ([1ecee30](https://github.com/maxbolgarin/gitbasher/commit/1ecee30aaae2e7c8b08a4aaf90584d0f6ba13811))
* **commit:** make the atomic-split flow safe with real-world repos ([19b52d3](https://github.com/maxbolgarin/gitbasher/commit/19b52d37e1fb08ff1f92b058a6e092e958cedd1c))
* **common:** never auto-confirm prompts on EOF; kill input spin loops ([f46fed6](https://github.com/maxbolgarin/gitbasher/commit/f46fed63b6560932a3ed24cd1c959162e40a1d3d))
* **wip:** never destroy WIP on restore failure; safer discovery ([be8674e](https://github.com/maxbolgarin/gitbasher/commit/be8674ea4e105fa8d410eb0cd272dfac6b3a3fce))
* **base:** pass all arguments to merge and rebase scripts ([91a40b6](https://github.com/maxbolgarin/gitbasher/commit/91a40b6a3e7ece803b1c5c0d6c641568db8ada3e))
* **base:** quote dispatch args, clean --version, document init/version ([d2b57ee](https://github.com/maxbolgarin/gitbasher/commit/d2b57ee7337b7d23f15bca7093898c7c311a7368))
* **completion:** re-sync all three shells with the real dispatch surface ([e7fb34b](https://github.com/maxbolgarin/gitbasher/commit/e7fb34bc6ba2da539548704992461da1a91fd532))
* real bash 3.2 runtime gaps in colors and read timeouts ([78f2eb2](https://github.com/maxbolgarin/gitbasher/commit/78f2eb20c717139a0bf53207fcbf6925a27844af))
* **merge:** reconcile divergent branches in pre-merge/rebase pull ([5f98352](https://github.com/maxbolgarin/gitbasher/commit/5f9835241e4a26514f6ed2ab9a14d8b51ef1720b))
* **build:** released bundle emits byte-identical artifacts to dev runs ([85aa24e](https://github.com/maxbolgarin/gitbasher/commit/85aa24e48813510c9707970bc37deed6fa11529d))
* **hook:** resolve hooks like git does; working templates and honest modes ([a889c1d](https://github.com/maxbolgarin/gitbasher/commit/a889c1d08e2706de20557c92d7d6bc6deb2f59c5))
* **rebase:** restore exact pre-pull state on abort; safer conflict loop ([65e9b4b](https://github.com/maxbolgarin/gitbasher/commit/65e9b4b529872db7a430160ee15a459afbeb33ac))
* **push:** show transfer progress only when a push or fetch runs long ([74a3d0c](https://github.com/maxbolgarin/gitbasher/commit/74a3d0c33ebef36b7ef4d27c32f8295defa709f9))
* **log:** stop dropping rows on macOS, guard non-TTY use, sanitize output ([d61e5cd](https://github.com/maxbolgarin/gitbasher/commit/d61e5cd0467b036b31e5b8b74917ee1cfe024d0c))
* **commit:** strip model reasoning preamble from AI commit messages ([0d61206](https://github.com/maxbolgarin/gitbasher/commit/0d61206a9738d4ca3c657cc156778a2ff772bb92))
* **ai:** trap safety, honest error handling, robust proxy/key management ([5bf3b1c](https://github.com/maxbolgarin/gitbasher/commit/5bf3b1cf3e24e925bb9fbfb59fadb6bed3bdc31d))
* **commit:** treat Enter as No at atomic-split (y/N) prompt ([e86bd0b](https://github.com/maxbolgarin/gitbasher/commit/e86bd0b19b9b907f5dfe748d64fd3228ee96a6f8))
* **merge:** unblock conflict resolution, stop arg shifts, honest checks ([5871ce3](https://github.com/maxbolgarin/gitbasher/commit/5871ce3202c4ff572f64f8ddfc8fb53d41037dbb))
* **squash:** work on bash 3.2, refuse merge ranges before the AI call ([1ce4ad2](https://github.com/maxbolgarin/gitbasher/commit/1ce4ad225a5c8cdfe7f076fdaa8ebe1d66d38436))
* **config:** working delete menu, safe writes, honest validation ([14ef2b8](https://github.com/maxbolgarin/gitbasher/commit/14ef2b86573930a407f88502f0099438e1909273))

### 📚 Documentation

* align README/FAQ/ARCHITECTURE with actual behavior ([9670681](https://github.com/maxbolgarin/gitbasher/commit/9670681b020c4c9ae252d4f2c26bdd3f00f29fa6))
* **log:** document the interactive browser, smart args and ai summary ([28c7957](https://github.com/maxbolgarin/gitbasher/commit/28c7957b2613a70456bc105fbd935e741faff588))
* **faq:** explain undo operation semantics and undo vs reset ([88dc9e4](https://github.com/maxbolgarin/gitbasher/commit/88dc9e46841f6592434e4eeeb27fb5897ec991c3))
* fix accuracy drift across README, FAQ, ARCHITECTURE, site and comments ([7f00931](https://github.com/maxbolgarin/gitbasher/commit/7f0093181812e9a2d9749368f941e47e6bb89560))
* use v5.0.0 in version-pin examples ([89d980c](https://github.com/maxbolgarin/gitbasher/commit/89d980cdfa34912b5ef8a95d49273ff3ac77a5ce))

### 📦 Code Refactoring

* make gitbasher run on bash 3.2 ([f575b05](https://github.com/maxbolgarin/gitbasher/commit/f575b055ed0813a965fd9d2b104d80f13ec142b6))
* make merged scope-dependency ordering bash 3.2 compatible ([746b9cd](https://github.com/maxbolgarin/gitbasher/commit/746b9cd96a74cb29394bfa41ad7671c4faf9c9c8))
* **diff:** move print_ai_summary to common.sh for cross-command reuse ([e1153e3](https://github.com/maxbolgarin/gitbasher/commit/e1153e39033e5fd9a526b90df6dab015e8132d4b))

### 🚨 Tests

* add 6 test suites for clone, commit splitting, and validation logic ([ec91278](https://github.com/maxbolgarin/gitbasher/commit/ec912787a8088a10fb07b76e0280c63ad567af98))
* add tests for ollama AI configuration and merge/rebase push modifiers ([4e35b3a](https://github.com/maxbolgarin/gitbasher/commit/4e35b3adbcfb0df8df4fcc694d377c4539415ddf))
* keep [@test](https://github.com/test) descriptions ASCII for bash 3.2 (bats name mangling) ([2ef48a7](https://github.com/maxbolgarin/gitbasher/commit/2ef48a79ef43f9dfb3b7b3ae65cb8d0736a9a031))
* make test code bash 3.2 compatible ([b7b81fa](https://github.com/maxbolgarin/gitbasher/commit/b7b81fab2b38cf0eb31a3d1906abab9c87a99beb))
* replace non-ASCII dash in test name that breaks bats under bash 3.2 ([6ac525b](https://github.com/maxbolgarin/gitbasher/commit/6ac525b2c788bac35fd9c941e714a14efec0482e))

### ⚙️ Continuous Integration

* add Docker bash:3.2 syntax + shim self-test job ([e6ec1e2](https://github.com/maxbolgarin/gitbasher/commit/e6ec1e273110b150244a4df375bb654b86f51dec))

## [4.1.0](https://github.com/maxbolgarin/gitbasher/compare/v4.0.0...v4.1.0) (2026-05-29)

### 🚀 Features

* **edit:** add `branch` mode to rename the current branch ([30cfd07](https://github.com/maxbolgarin/gitbasher/commit/30cfd071d49e73761f7853b8ca9643d0db50d9b4))
* **edit:** add `gitb edit` and retire the commit `last` action ([51d3ca2](https://github.com/maxbolgarin/gitbasher/commit/51d3ca2c6d1e41a7dac506d05723cb7469b7ce41))
* **edit:** add `pick` mode to reword any recent commit ([175cbd7](https://github.com/maxbolgarin/gitbasher/commit/175cbd73d29cb14c3f436b543b150b4e7cd6fd2d))
* **site:** add Astro marketing site for GitHub Pages ([df1c1eb](https://github.com/maxbolgarin/gitbasher/commit/df1c1eb3925bd73156abd87150638ac74d73f9df))
* **clone:** add gitb clone command ([ac377b2](https://github.com/maxbolgarin/gitbasher/commit/ac377b2e76378742289b632e117eca07bb3b09da))
* **commit:** allow push modifier on revert ([cdb86b4](https://github.com/maxbolgarin/gitbasher/commit/cdb86b4c643db3d4fc2c2a68f2e931670729d04c))
* **gitb:** allow running outside a git repository for global commands ([8eeeefe](https://github.com/maxbolgarin/gitbasher/commit/8eeeefef3839a43fd009cfa3f57f8ed6628fb259))
* **commit:** cap atomic split at a configurable number of scopes ([15103d8](https://github.com/maxbolgarin/gitbasher/commit/15103d8234a54d6b329b921b1d412cfa8b4598e3))
* **push:** retry transient network failures with exponential backoff ([80f8d32](https://github.com/maxbolgarin/gitbasher/commit/80f8d32709aaf5759689f48be6f75979cdf40fe0))
* **pull:** stream git fetch progress live during gitb pull ([92ed00d](https://github.com/maxbolgarin/gitbasher/commit/92ed00de9b8c4cc9ed954ad0d59a92c83361569c))

### 🐛 Bug Fixes

* **gitb:** escape command substitution in macOS upgrade instructions ([f61db10](https://github.com/maxbolgarin/gitbasher/commit/f61db101c97527d101d6787e4b0aca625c8f55e5))
* **commit:** honor push modifier when amending ([f5d2664](https://github.com/maxbolgarin/gitbasher/commit/f5d26640ab4ded146fcf1231200e99a1ddb91e9a))
* **commit:** strip leading/trailing separators from auto scopes ([3fee1c8](https://github.com/maxbolgarin/gitbasher/commit/3fee1c8456ae6a171618efbbba87d81dfc5a9c6a))

## [4.0.0](https://github.com/maxbolgarin/gitbasher/compare/v3.10.2...v4.0.0) (2026-05-04)

### ⚠ BREAKING CHANGES

* there are a lot of improvements in that release and it deserves a major release

### 🚀 Features

* **commit:** accept multi-word mode tokens ([e9c5c76](https://github.com/maxbolgarin/gitbasher/commit/e9c5c76bb6fefbdb49cc92fe05ae0c46a99e029b))
* **scripts:** add 'new feature' ([d0220c0](https://github.com/maxbolgarin/gitbasher/commit/d0220c08cf1832ef8b57c920ab508e04f09d00e5))
* **gitb:** add ai commit message generation to split and commit menus and refactor logic ([afc7fdd](https://github.com/maxbolgarin/gitbasher/commit/afc7fddb59124f7126dc7f33a884de83230e5687))
* **squash:** add ai-driven gitb squash that rebases branch commits into changelog-ready history ([1e8f9ff](https://github.com/maxbolgarin/gitbasher/commit/1e8f9ff0d0d2674a8853267c72d77b27a7bbeb9c))
* **gitb:** add ai-powered squash command and update version ([12a0522](https://github.com/maxbolgarin/gitbasher/commit/12a05229bdd94cfebe29a706750fd7c8b9a15b86))
* **commit:** add aispl/aisplp short aliases for aisplit/aisplitp ([6a439fe](https://github.com/maxbolgarin/gitbasher/commit/6a439fe4ad05da053b71d441c7e08cacfad5e33a))
* **completion:** add bash, fish, and zsh shell completions and install script ([20b65e8](https://github.com/maxbolgarin/gitbasher/commit/20b65e8fd96dd1523133bad313e33a4a58c8600a))
* **wip:** add branch and worktree backends to gitb wip ([dc8a943](https://github.com/maxbolgarin/gitbasher/commit/dc8a9435b51887b605898ea92a43b0604406e7ee))
* **wip:** add branch and worktree backends to gitb wip ([091036f](https://github.com/maxbolgarin/gitbasher/commit/091036f0fb15d4a185286f095fe8ab9e58450033))
* **wip:** add branch and worktree backends to gitb wip ([10da8bc](https://github.com/maxbolgarin/gitbasher/commit/10da8bc261166e7ff99229fff6ecd3c48a3f983c))
* **scripts:** add completion.sh and update base.sh and config.sh to use it ([295b421](https://github.com/maxbolgarin/gitbasher/commit/295b42111f82224fbe21962ce699098449cbf72e))
* **pull,sync:** add dry-run mode that previews incoming commits without modifying local refs ([939308e](https://github.com/maxbolgarin/gitbasher/commit/939308e1ac44c7a055941293a1bd2b8cfaa29c87))
* **scripts:** add embedded repo detection to fast add and refactor worktree add options ([df7cd26](https://github.com/maxbolgarin/gitbasher/commit/df7cd264c463470da83d00a53e2d2056d5b80545))
* **worktree:** add full git worktree support ([ebc0180](https://github.com/maxbolgarin/gitbasher/commit/ebc0180f22f6a1c0df10de577d2b248aea7c1619))
* **worktree:** add full git worktree support ([382bd81](https://github.com/maxbolgarin/gitbasher/commit/382bd81744dde457c215cdf571cacc507377fbf6))
* **worktree:** add full git worktree support ([3f01f80](https://github.com/maxbolgarin/gitbasher/commit/3f01f80b6d21daf8e69677937f6454dbc9c7de0e))
* **makefile:** add install and uninstall completion targets ([89dc52d](https://github.com/maxbolgarin/gitbasher/commit/89dc52d8f74186de65bc692cfa3cf1ffd01d957f))
* **install:** add install.sh one-liner installer ([cd6a588](https://github.com/maxbolgarin/gitbasher/commit/cd6a588bda10144f463fec7789538a0f2c148bbf))
* **ai:** add OpenAI and Ollama provider support ([a7c5e87](https://github.com/maxbolgarin/gitbasher/commit/a7c5e877f04ede66c0fff73c9fbe67c844ea5c92))
* **origin:** add origin command for init/set/change/rename/remove remote ([a62a5da](https://github.com/maxbolgarin/gitbasher/commit/a62a5da7838156eb27891a8aa3d77a3b47d3cdcd))
* **gitb:** add per-provider ai api key management and improve configuration display ([fe115f7](https://github.com/maxbolgarin/gitbasher/commit/fe115f789ae9ce2a92fd5db6eafdbb2cb8e62a62))
* **scripts:** add per-provider ai key management and fix openai token parameter naming ([97761b3](https://github.com/maxbolgarin/gitbasher/commit/97761b37008a41e25ec539e7c827c3a4175ed41a))
* **gitb:** add pull and sync dry-run modes, and wip worktree and branch backends ([92b43c1](https://github.com/maxbolgarin/gitbasher/commit/92b43c1f5e33829021d76fcc6fc64038b1798237))
* **gitb:** add reset preview and confirmation to reset.sh and update reset help text ([ed26d84](https://github.com/maxbolgarin/gitbasher/commit/ed26d84a0ff97a2943bb011bdd0d90ff5f380728))
* **scripts:** add reset preview and confirmation to reset.sh ([f13a482](https://github.com/maxbolgarin/gitbasher/commit/f13a482b86b2325882e9753a59de3f37bbd350b2))
* add scheduled tasks lock file ([832cf70](https://github.com/maxbolgarin/gitbasher/commit/832cf703841e3d87c94cc9edffd5b5f895540946))
* **scripts:** add sha-256 verification to updates, enable pipefail, and improve ai key storage flow ([1045447](https://github.com/maxbolgarin/gitbasher/commit/10454477b70993239b4ecb4462b6b9430e2a514a))
* **gitb:** add tab completion management to config and update version ([7710882](https://github.com/maxbolgarin/gitbasher/commit/771088264dea1c3dc3a433a815e26adf71890473))
* **dist:** add uninstall command and improve ai provider configuration flow ([5453967](https://github.com/maxbolgarin/gitbasher/commit/54539670d1789ad4ad3fe42490ef6df4d3fd2e1b))
* **scripts:** add uninstall command and secure silent input for api keys ([7e25f67](https://github.com/maxbolgarin/gitbasher/commit/7e25f675e503214298a146c3b89bbc586f44d7cd))
* **scripts:** add update command and integrate ai commit message generation into split menus ([a167f88](https://github.com/maxbolgarin/gitbasher/commit/a167f884caaf2d910e4a0419fedd4802ec0a9a43))
* **commit:** AI-refined scope grouping and ultrafast (ff) mode ([9982fc2](https://github.com/maxbolgarin/gitbasher/commit/9982fc296a8814f3f59c6dd6794756749b3a4a8e))
* **install:** default to ~/.local/bin, add --sudo flag ([58948a9](https://github.com/maxbolgarin/gitbasher/commit/58948a92b79a979e5e6830c5eb212ec0e423785d))
* **ai:** include all files with their action so big commits stay legible when diff is truncated ([2a5ff3c](https://github.com/maxbolgarin/gitbasher/commit/2a5ff3c5182f68cfe32540d6c34b15f473df513c))
* **commit:** offer atomic per-scope split for multi-scope staged changes ([a1b0080](https://github.com/maxbolgarin/gitbasher/commit/a1b00807174a93235f38e4c51125663a83497844))
* **ai:** per-task model defaults picked for speed/cost/quality ([3ffd543](https://github.com/maxbolgarin/gitbasher/commit/3ffd543e5e78c268d66c732efc889a7eb00649ac))
* **ai:** require scopes when detectable, support multi-scope syntax, mention changelog purpose ([a2722b2](https://github.com/maxbolgarin/gitbasher/commit/a2722b2a69a54ca5754707018edbfd529156845e))
* **push:** richer post-push and post-tag links ([fa81b61](https://github.com/maxbolgarin/gitbasher/commit/fa81b611e14b596ae312db6693f1978713907d83))
* **push:** richer post-push and post-tag links ([1d1f3ac](https://github.com/maxbolgarin/gitbasher/commit/1d1f3ac6a56c5cea2bfe8f4f920e7563a6896bc3))
* **origin:** show all available web links in origin info ([038853a](https://github.com/maxbolgarin/gitbasher/commit/038853a49741d3b4fdbffdb68530079a4a4011f9))
* **ai:** tune sampling, cap output cost, and expand configurable diff payload ([694fbd0](https://github.com/maxbolgarin/gitbasher/commit/694fbd00769030efb40f2f26182c8538587ee614))

### 🐛 Bug Fixes

* **push:** align post-push links regardless of label length ([7848c27](https://github.com/maxbolgarin/gitbasher/commit/7848c272d592dff45f8b9016730d9cc4d103c103))
* **push:** align post-push links regardless of label length ([ffdc57b](https://github.com/maxbolgarin/gitbasher/commit/ffdc57b7db6daac6ccc4dc798f2cdbc6faa068d8))
* **gitb:** handle index.lock, update version, and improve git commands and conflict resolution ([cb28d18](https://github.com/maxbolgarin/gitbasher/commit/cb28d1855b26a65fde04aef4935510f8c823aab3))
* handle uppercase Cyrillic in normalize_key and broaden get_repo ([811ce74](https://github.com/maxbolgarin/gitbasher/commit/811ce74a9e29f130e59872e4d01b77e694f089c5))
* **ai:** make the model cover ALL changes in multi-change commits ([6ad3384](https://github.com/maxbolgarin/gitbasher/commit/6ad3384970b2e371ed5cbe17cccd180e3e19afb4))
* **ai:** preserve prompt newlines in JSON encoding and fix prompt typos ([6fabcfe](https://github.com/maxbolgarin/gitbasher/commit/6fabcfe0bda8f643a4d29422423e059b0395b867))
* **ai:** raise per-mode max_tokens caps to avoid truncating valid messages ([06aeadd](https://github.com/maxbolgarin/gitbasher/commit/06aeadde882bfdc3f30c439a6526e7047b2a5cdc))
* **merge:** treat already-committed merge as success ([aea894f](https://github.com/maxbolgarin/gitbasher/commit/aea894f510256222549c3d581efee68241bd4563))
* **gitb:** update version, add rejected messages to ai prompt, and refine commit split and help output ([4bcba02](https://github.com/maxbolgarin/gitbasher/commit/4bcba020c54194c479f5a933ec01a580b677548d))

### ⚡ Performance Improvements

* bundle gitb binary in npm tarball to skip postinstall download ([5f683c0](https://github.com/maxbolgarin/gitbasher/commit/5f683c0b151ac91f6f0f4e5f0dd754e5809eecf8))

### 📚 Documentation

* **readme:** 8new README ([d613e93](https://github.com/maxbolgarin/gitbasher/commit/d613e9393c802a7df2721d1fe5559a94d5ed9ebe))
* **.github:** add bug report, feature request, and pull request templates ([6a33c96](https://github.com/maxbolgarin/gitbasher/commit/6a33c960817c8c1ad2bb76f2a044c31290f3afd4))
* add codecov badge to readme ([573b6b5](https://github.com/maxbolgarin/gitbasher/commit/573b6b5b512de0d3c270cab226c4764d01f546ab))
* **readme:** add common git errors and solutions section ([51b0330](https://github.com/maxbolgarin/gitbasher/commit/51b03300397408ba27781b3bb75ca6e6d3d34ca2))
* add contributing guide and audit remediation checklist and fix wget https-only flag ([fbb152f](https://github.com/maxbolgarin/gitbasher/commit/fbb152fab6d5ff30742cb10f0949f4b98c563a64))
* add faq and troubleshooting guides, update contributing docs, and improve installer feedback ([9a1e7b5](https://github.com/maxbolgarin/gitbasher/commit/9a1e7b547fa7a7332d0c9418e9da2828b28d63b7))
* **readme:** add uninstall instructions ([7cd4b84](https://github.com/maxbolgarin/gitbasher/commit/7cd4b84ecacf06ed4d0a531ccccb5a6b146d630f))
* add v4 release readiness report and remove codecov badge from readme ([320ed43](https://github.com/maxbolgarin/gitbasher/commit/320ed439264cdd0870c75d7299f43441fe775ee4))
* **readme:** cover all commands and adapt for top-repo discoverability ([a1e035b](https://github.com/maxbolgarin/gitbasher/commit/a1e035bcd923d7b6fbce10ef4d72517a95f0bb3a))
* prepare for 4 version ([053541f](https://github.com/maxbolgarin/gitbasher/commit/053541f12a9bb3caf14697be57c82554a5deb7c9))
* **ai:** refresh provider defaults to May 2026 picks and document them ([97b46f8](https://github.com/maxbolgarin/gitbasher/commit/97b46f82c1fcb0f39dcc02d57875ec2d7551d5ad))
* **commit:** restructure help and accept --help/-h on every command ([514067d](https://github.com/maxbolgarin/gitbasher/commit/514067d7c7664b4c17818137c1a186a4be4c14b3))
* update audit markdown to reflect dry-run scope and remove completed items ([9ca01c5](https://github.com/maxbolgarin/gitbasher/commit/9ca01c5411c9a092f3a856fbee3b021d64e50725))
* update audit with 5 new test suites and kcov coverage job ([c717913](https://github.com/maxbolgarin/gitbasher/commit/c7179136e05aa49aff4bcb4fea813cdfad19f61c))
* update commit demonstration gif ([5a131c4](https://github.com/maxbolgarin/gitbasher/commit/5a131c4eae2cfd61c664cafec42650cb7d5de946))
* update docs ([3878f1f](https://github.com/maxbolgarin/gitbasher/commit/3878f1ff1c2dcdc2d664fac2c4ecd3b5acb2a080))
* update README ([6349b7c](https://github.com/maxbolgarin/gitbasher/commit/6349b7c13ffede6952484d4c381b8ee6d77f4922))
* update readme with command alias changes and cleanup outdated sections ([451a5dc](https://github.com/maxbolgarin/gitbasher/commit/451a5dc54ae725de84eb7b7f79771cfa853329d9))
* update uninstall instructions and add lifecycle command to readme ([baf856c](https://github.com/maxbolgarin/gitbasher/commit/baf856c9407ba6788a774e8e311c58102991e619))

### 📦 Code Refactoring

* **gitb:** add blank lines to commit prompts for readability ([efb8489](https://github.com/maxbolgarin/gitbasher/commit/efb8489164fa280b22d2bf8f6c0762804a253c44))
* **scripts:** add blank lines to commit prompts for readability ([5de9b24](https://github.com/maxbolgarin/gitbasher/commit/5de9b24da739db3941b7757654ddebd4802f0be2))
* **scripts:** add kcov-skip markers to 19 git utility scripts ([18d7af9](https://github.com/maxbolgarin/gitbasher/commit/18d7af945e51ec9da51b51fea46100d8bcce6a21))
* **scripts:** add kcov-skip markers to base.sh to exclude entrypoint from coverage metrics ([b96c196](https://github.com/maxbolgarin/gitbasher/commit/b96c196177cf25e0cdc9e961a8ba518ada9e36a8))
* **scripts:** add kcov-skip markers to help menus and sensitive functions across all scripts ([e2e08d1](https://github.com/maxbolgarin/gitbasher/commit/e2e08d1bbd2b5f4254980e5bbb4aacce82221593))
* **commit:** add logic to strip redundant scopes from commit messages ([9d7b056](https://github.com/maxbolgarin/gitbasher/commit/9d7b05620258d15568d782799c742bb20772c588))
* **gitb:** broaden get_repo and add 5 repo URL helpers ([a8bad93](https://github.com/maxbolgarin/gitbasher/commit/a8bad939335495569116556950c072b38d11eeae))
* **commit:** delegate unpushed commit handling to push_script for unified push UX ([462176a](https://github.com/maxbolgarin/gitbasher/commit/462176a9666e3a5d105287ab6e43ca5f9f2e20cf))
* **dist:** enable strict mode and improve path handling in build script ([3a2023b](https://github.com/maxbolgarin/gitbasher/commit/3a2023bcca4baee5ccbdcc00ed3360b076b7ae9b))
* **scripts:** extract commit type menu to a new function and update prompts ([d6114a5](https://github.com/maxbolgarin/gitbasher/commit/d6114a58635dbe2ccbaf0fa331cbe275e557ee15))
* **ai:** forbid multi-scope syntax in generated commit messages ([fe149b1](https://github.com/maxbolgarin/gitbasher/commit/fe149b11bba6e2d1f9151c2a783f2a2350c9e9c4))
* **commit:** gate AI in split flow on llm intent + add aisplit modes ([fbba1b8](https://github.com/maxbolgarin/gitbasher/commit/fbba1b839eefdc26829a926f0fa58afecaf507b1))
* **scripts:** implement status-aware staging to correctly handle deletions during commit splitting ([f8f9641](https://github.com/maxbolgarin/gitbasher/commit/f8f96411e44b482a7387487d22089c8dcb56f17c))
* **scripts:** improve ai proxy validation, branch checkout, and commit split output ([c4b873e](https://github.com/maxbolgarin/gitbasher/commit/c4b873e81cb37d445b70a8954f8fa32fc55ac4b3))
* **scripts:** improve error messages and help output across 24 scripts ([06e90d3](https://github.com/maxbolgarin/gitbasher/commit/06e90d3afd1106af32737300727dc2d06dc7dfc7))
* **scripts:** improve git command quoting and add shell tracing disable to ai.sh ([6eba4df](https://github.com/maxbolgarin/gitbasher/commit/6eba4df930270a2b10fa454a4da0cae3ba9936e1))
* **worktree:** improve path logic, add lock/unlock, and manage options ([dc5a26e](https://github.com/maxbolgarin/gitbasher/commit/dc5a26edfc338e414599416cb0a029bd5a8c6074))
* **commit:** improve scope detection logic for monorepo paths and filename stems ([46870f1](https://github.com/maxbolgarin/gitbasher/commit/46870f1081f6352582e54b40a9bbbe3e2c716bad))
* **dist:** improve split commit UI formatting and bump version ([f4487d8](https://github.com/maxbolgarin/gitbasher/commit/f4487d83c45f0169175d0d3170206eedc4045294))
* **scripts:** improve worktree path logic, help text, and wip worktree defaults ([633e738](https://github.com/maxbolgarin/gitbasher/commit/633e738243cae6504c283465f7fb1361bf82512e))
* **wip:** merge wip/unwip into single wip up/down command ([064ddd9](https://github.com/maxbolgarin/gitbasher/commit/064ddd9f4c291ab1b15eaf89c82ca8091e64ece1))
* **scripts:** prefix wip worktree paths with repo directory name to prevent collisions ([8f7d542](https://github.com/maxbolgarin/gitbasher/commit/8f7d542bf4497401651b846a4f58e24daee699ef))
* **completion:** remove bash, fish, and zsh shell completions and install script ([7cd1986](https://github.com/maxbolgarin/gitbasher/commit/7cd19864d4ee96fc06cdf7f0b4749f699f5c19f5))
* **makefile:** remove install and uninstall completion targets ([d5ea7af](https://github.com/maxbolgarin/gitbasher/commit/d5ea7af45d468d65ce74d33523d3b9550eed446c))
* **scripts:** remove kcov-skip markers from 24 scripts ([f3d9e2a](https://github.com/maxbolgarin/gitbasher/commit/f3d9e2aa6e8c7e549baa17df4474f72a61b70c0f))
* **scripts:** replace read with read_editable_input across 10 scripts ([c2177f3](https://github.com/maxbolgarin/gitbasher/commit/c2177f331db1ba6d1d65050da6b0413d8efb7a4f))
* **gitb:** replace read with read_editable_input and update version ([07e89ee](https://github.com/maxbolgarin/gitbasher/commit/07e89ee292efb00747c509048fb0da610f30ae1b))
* standardize help menus, improve curl security, and add URL builder tests ([4e6ffff](https://github.com/maxbolgarin/gitbasher/commit/4e6ffff82ec2afe4c715bd2d2fce9e9d0bbbd534))
* **scripts:** standardize help menus, improve curl security, and harden temp file creation ([c8f9f8f](https://github.com/maxbolgarin/gitbasher/commit/c8f9f8f3379b622f3e9c2638ea9bd95517c8a642))
* **dist:** swap stash and status command aliases and optimize scope detection logic ([cf57089](https://github.com/maxbolgarin/gitbasher/commit/cf57089057de4a6eb6d9cf30f03e0dc94ca48956))
* **scripts:** swap stash and status command aliases and optimize scope detection logic ([f77eb2f](https://github.com/maxbolgarin/gitbasher/commit/f77eb2fb9305ff054f1750237b2461e4c5850b13))
* **ai:** tune prompts for Claude (system message, examples, tagged sections) ([9fd612b](https://github.com/maxbolgarin/gitbasher/commit/9fd612b01412c799e7a5b3b2e3593dfdadb6ab86))
* **ai:** unify prompt builders, switch to XML-tagged prompts, add regenerate ([7c71c9d](https://github.com/maxbolgarin/gitbasher/commit/7c71c9d81f7d0dbbd4a99b7df79b40a8d7962148))
* **scripts:** update commit type menu styling to highlight plain option ([8180dde](https://github.com/maxbolgarin/gitbasher/commit/8180dde601147acae20403447428ecd26023d1c1))
* **scripts:** update help text for clarity and add common flows and tips sections ([030d1d7](https://github.com/maxbolgarin/gitbasher/commit/030d1d755dcb0ed5050375e9720c4bacf23d4b70))
* **gitb:** update version and improve error messages and prompts ([6087b85](https://github.com/maxbolgarin/gitbasher/commit/6087b85d769d0fa2edc59fd5e9ef024e5837acc2))

### 🚨 Tests

* **commit:** add 10 tests for commit prompt, split, and ai message generation ([6dbfb7c](https://github.com/maxbolgarin/gitbasher/commit/6dbfb7cbb37c3f57209bb700f8eb8a4ec3740d1c))
* add 5 new test suites for commit, detached head, fast stage, cleanup, and wip undo ([f3eaabc](https://github.com/maxbolgarin/gitbasher/commit/f3eaabc0ec66522b6cd055f0fcb11a537fa5d0d1))
* **tests:** add 5 test suites covering ai curl, build script, bundle integration, completion, and config ([fc75ba9](https://github.com/maxbolgarin/gitbasher/commit/fc75ba94754e5624514d3aa3b30cecb04eaa7fa3))
* **commit:** add bats tests for commit prompt rendering helpers ([578988f](https://github.com/maxbolgarin/gitbasher/commit/578988f01e8460bcd3424b1bde531d2d4de75bc6))
* **base:** add bats tests for top-level command routing and help ([8bd2fd9](https://github.com/maxbolgarin/gitbasher/commit/8bd2fd906c1dae7639172b70a9ee367769d793d6))
* **commit:** add commit validation tests and update reset prompt and embedded repo colors ([9eb6e4f](https://github.com/maxbolgarin/gitbasher/commit/9eb6e4f3df9bf56647c762793de118d9015f1416))
* **tests:** add gitleaks exception to api key masking test fixture ([bd1759b](https://github.com/maxbolgarin/gitbasher/commit/bd1759b6c3224ab77628165c7bf346b5cf0a460e))
* **tests:** add read_editable_input escape key test ([918d85c](https://github.com/maxbolgarin/gitbasher/commit/918d85ca89ccd5972f4872471bdf921533c31630))
* **tests:** add regression test suite for monorepo scope detection and split logic ([7f6b83c](https://github.com/maxbolgarin/gitbasher/commit/7f6b83c75220c755a1c1b110bb148b4ae9130a80))
* add regression test suite for redundant scope stripping logic ([91ac5a0](https://github.com/maxbolgarin/gitbasher/commit/91ac5a08795f910122075ea7c054ffb14e99e7ad))
* **tests:** add regression test suite for status-aware commit splitting and deletion handling ([8776537](https://github.com/maxbolgarin/gitbasher/commit/8776537de9cddb5ebeb1f6700b8b4c57cd120550))
* **tests:** add regression test suite for unpushed commit UI duplication ([2eae4d4](https://github.com/maxbolgarin/gitbasher/commit/2eae4d4834439d0a58ddb5cf5be6727a7a2f66b0))
* **tests:** add smoke test suite to verify script sourcing and improve coverage tracking ([b52e68f](https://github.com/maxbolgarin/gitbasher/commit/b52e68f8511058b30a23bc0556fe2e7319ffa446))
* **base:** add test for common flows and tips in top-level help output ([2ec88f4](https://github.com/maxbolgarin/gitbasher/commit/2ec88f44ad9123b5d58c6cd5017fb0b40a7796f9))
* **tests:** add tests for 'new feature' ([3b60c3e](https://github.com/maxbolgarin/gitbasher/commit/3b60c3e82804655ef6f7ab75d08a62e4eaa187ff))
* add tests for ai configuration helpers and update script logic ([ed9aca6](https://github.com/maxbolgarin/gitbasher/commit/ed9aca6dc52302c46c3247c9b2dafbad16b5d60c))
* **tests:** add tests for read_silent_input cancellation and input handling ([64ce77c](https://github.com/maxbolgarin/gitbasher/commit/64ce77c05f532480c2e39b89e894d7ca59a6a1e2))
* **tests:** canonicalize temporary directory path in wip worktree test ([4e28fff](https://github.com/maxbolgarin/gitbasher/commit/4e28fff3a68f17305ba5e6b27d392cc2ca0f0397))
* **reset:** fix stdin redirection in bats tests for reset_script ([0476642](https://github.com/maxbolgarin/gitbasher/commit/0476642294d229d0d652f4889f4323ef8b1a461b))
* **tests:** update commit prompt test expectations for plain option styling ([486f2d7](https://github.com/maxbolgarin/gitbasher/commit/486f2d7684542f65867ae1fe015eac3ee7dc046d))
* **tests:** update smoke test suite to verify script sourcing and help dispatch for coverage tracking ([a242fa1](https://github.com/maxbolgarin/gitbasher/commit/a242fa1cf11a83d2cc7b27edaf97fbaee19cc658))
* **test_commit_prompt:** update split AI suggestion decline test to expect blank line ([92af66d](https://github.com/maxbolgarin/gitbasher/commit/92af66dc10e13fed53933403c8765d39c11d14d5))

### 🛠 Build System

* add coverage job and update gitb with wip backend changes ([09c5447](https://github.com/maxbolgarin/gitbasher/commit/09c5447ce6d3ef3994658f31d43ffbfde20fc390))
* **.github:** make better workflows ([d213111](https://github.com/maxbolgarin/gitbasher/commit/d21311131fc31cc734d09a8495691119636c6213))
* **gitb:** update build ([b2a4384](https://github.com/maxbolgarin/gitbasher/commit/b2a43848419263f9c8a2e7e28d02b605c023442c))

### ⚙️ Continuous Integration

* **.github:** add dependabot, implement linting and security gates, and add release concurrency guard ([1a81bdb](https://github.com/maxbolgarin/gitbasher/commit/1a81bdb4483b107ec9ef2a9101aa65eabd4ff850))
* **.github:** install bash on macos and update test execution path ([5f88f76](https://github.com/maxbolgarin/gitbasher/commit/5f88f76ed090b99f2accfae7dc26e6cfb620ab92))
* **.github:** pin coverage job to ubuntu-22.04 and add codecov upload step ([69b4e71](https://github.com/maxbolgarin/gitbasher/commit/69b4e71e2ce5c25d1daadaf80f3726ce97df8058))
* **build:** refine kcov coverage configuration and exclude install.sh from metrics ([7327dcc](https://github.com/maxbolgarin/gitbasher/commit/7327dcc60da48d5fb77b20147d37f24141df5b5b))
* remove npm audit and coverage jobs from build workflow ([818193d](https://github.com/maxbolgarin/gitbasher/commit/818193d6d13e60017078d52bfd3e3d95dd7dcf9f))
* **build:** set fetch-depth to 0 for gitleaks action ([20ec60a](https://github.com/maxbolgarin/gitbasher/commit/20ec60a4f05d0c7ee19508b7342e445b06c923e3))
* **workflows:** simplify kcov execution and remove codecov upload from build pipeline ([28b8d40](https://github.com/maxbolgarin/gitbasher/commit/28b8d4080ec6a82d7d9d9c78401a64cb182a8dd0))
* **build:** upgrade node version to 22 in build and release workflows ([3cd41a2](https://github.com/maxbolgarin/gitbasher/commit/3cd41a2ff5f30a109c1f3bf648985f8d88226a0b))

<!--
This file is regenerated by @semantic-release/changelog on every release.
Do not edit by hand. To affect the changelog, write a Conventional Commit
(feat:, fix:, perf:, refactor:, docs:, build:, revert:, BREAKING CHANGE:).
Releases prior to the introduction of this file are recorded in GitHub Releases:
https://github.com/maxbolgarin/gitbasher/releases
-->
