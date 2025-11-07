# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2025-11-07

### Added

- **Improved Installation Methods**
  - Created universal `install.sh` script with automatic system detection
  - Added Homebrew formula for macOS/Linux installation
  - Added APT packaging for Debian/Ubuntu distributions
  - Added version pinning support for installations
  - Added checksum verification for secure downloads
  - Automatic PATH configuration in install script

- **New `gitb doctor` Command**
  - Comprehensive dependency checking
  - Git configuration verification
  - Repository status diagnostics
  - System information display
  - Optional features detection (AI, shellcheck, bats)
  - Helpful error messages and fix suggestions

- **Version Support**
  - Added `--version` flag to display current version
  - Added `VERSION` file for version tracking

- **Documentation**
  - Added `PACKAGING.md` with detailed packaging instructions
  - Added `CHANGELOG.md` to track version changes
  - Updated README with multiple installation methods

### Changed

- Reorganized installation documentation in README
- Updated installation process to support multiple package managers
- Made `gitb doctor` and `gitb --version` work outside git repositories

### Fixed

- Improved version command to execute before first-run configuration

## [2.x.x] - Previous Releases

See GitHub releases for earlier version history.

[3.0.0]: https://github.com/maxbolgarin/gitbasher/releases/tag/v3.0.0
