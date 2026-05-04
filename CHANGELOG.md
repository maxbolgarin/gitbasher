# Changelog

All notable changes to gitbasher are generated automatically by [semantic-release](https://github.com/semantic-release/semantic-release) from [Conventional Commits](https://www.conventionalcommits.org/) on `main`. The project follows [Semantic Versioning](https://semver.org/).

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
