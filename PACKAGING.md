# Packaging Guide for gitbasher

This document describes how to create and publish releases for gitbasher.

## Prerequisites

- [GitHub CLI](https://cli.github.com/) (`gh`) installed
- Access to the repository
- Proper credentials for package repositories

## Release Process

### 1. Update Version

Update the version number in:
- `VERSION` file
- `scripts/base.sh` (in the --version handler)
- `Formula/gitbasher.rb` (url and version)
- `debian/changelog` (add new entry)

### 2. Build the Distribution

```bash
make build
```

This creates the `dist/gitb` file by combining all scripts.

### 3. Create Release Tarball and Checksums

```bash
# Create tarball
VERSION=3.0.0
git archive --format=tar.gz --prefix=gitbasher-${VERSION}/ -o gitbasher-${VERSION}.tar.gz HEAD

# Generate checksums
sha256sum dist/gitb > dist/gitb.sha256
sha256sum gitbasher-${VERSION}.tar.gz > gitbasher-${VERSION}.tar.gz.sha256
```

### 4. Create GitHub Release

```bash
# Create a git tag
git tag -a v${VERSION} -m "Release version ${VERSION}"
git push origin v${VERSION}

# Create GitHub release
gh release create v${VERSION} \
  --title "v${VERSION}" \
  --notes "Release notes here..." \
  dist/gitb \
  dist/gitb.sha256 \
  gitbasher-${VERSION}.tar.gz \
  gitbasher-${VERSION}.tar.gz.sha256
```

Or use semantic-release (configured in `.releaserc.json`):

```bash
# Semantic release will automatically create releases based on commit messages
npx semantic-release
```

## Package Distribution

### Homebrew (macOS/Linux)

1. Update the formula in `Formula/gitbasher.rb`:
   - Update version
   - Update URL to point to the new release
   - Calculate and update SHA256

```bash
# Calculate SHA256 for Homebrew
sha256sum gitbasher-${VERSION}.tar.gz | cut -d' ' -f1
```

2. Create/update the Homebrew tap repository:

```bash
# If you have a homebrew-tap repository
cd /path/to/homebrew-tap
cp /path/to/gitbasher/Formula/gitbasher.rb Formula/
git add Formula/gitbasher.rb
git commit -m "gitbasher: update to ${VERSION}"
git push
```

3. Test the formula:

```bash
brew install --build-from-source Formula/gitbasher.rb
brew test gitbasher
brew audit --strict gitbasher
```

### APT (Debian/Ubuntu)

#### Using Gemfury or similar

1. Build the Debian package:

```bash
# Install build dependencies
sudo apt install debhelper devscripts

# Build package
dpkg-buildpackage -us -uc -b

# This creates gitbasher_${VERSION}_all.deb in parent directory
```

2. Upload to package repository:

```bash
# Upload to Gemfury (example)
curl -F package=@../gitbasher_${VERSION}_all.deb https://${FURY_TOKEN}@push.fury.io/${FURY_ACCOUNT}/
```

#### Self-hosted repository

1. Create repository structure:

```bash
mkdir -p apt-repo/{conf,dists/stable/main/binary-amd64}
```

2. Create `apt-repo/conf/distributions`:

```
Origin: gitbasher
Label: gitbasher
Codename: stable
Architectures: all amd64
Components: main
Description: gitbasher APT repository
```

3. Add package:

```bash
cd apt-repo
reprepro includedeb stable ../gitbasher_${VERSION}_all.deb
```

4. Serve via web server (nginx, Apache, or GitHub Pages)

### Alternative: GitHub Releases as APT Repository

You can also set up GitHub Releases as an APT repository using tools like:
- [deb-s3](https://github.com/deb-s3/deb-s3)
- [aptly](https://www.aptly.info/)
- [reprepro](https://salsa.debian.org/debian/reprepro)

## Testing Installation Methods

After publishing a release, test all installation methods:

### Test Homebrew

```bash
brew uninstall gitbasher 2>/dev/null || true
brew install maxbolgarin/tap/gitbasher
gitb --version
gitb doctor
```

### Test APT

```bash
sudo apt remove gitbasher 2>/dev/null || true
sudo apt update
sudo apt install gitbasher
gitb --version
gitb doctor
```

### Test Install Script

```bash
rm -f ~/.local/bin/gitb /usr/local/bin/gitb 2>/dev/null || true
curl -sSL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/install.sh | bash
gitb --version
gitb doctor
```

### Test Manual Installation

```bash
VERSION=v3.0.0
curl -SL https://github.com/maxbolgarin/gitbasher/releases/download/$VERSION/gitb -o /tmp/gitb
chmod +x /tmp/gitb
/tmp/gitb --version
/tmp/gitb doctor
```

## Continuous Integration

Consider setting up GitHub Actions to automate:
- Building on each commit
- Running tests
- Creating releases on version tags
- Publishing to package repositories

Example workflow (`.github/workflows/release.yml`):

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: make build
      - name: Create checksums
        run: |
          sha256sum dist/gitb > dist/gitb.sha256
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            dist/gitb
            dist/gitb.sha256
```

## Troubleshooting

### Homebrew formula fails to build

- Check that the tarball URL is accessible
- Verify SHA256 checksum matches
- Test locally: `brew install --build-from-source --verbose --debug Formula/gitbasher.rb`

### APT package installation fails

- Verify package structure: `dpkg -c gitbasher_${VERSION}_all.deb`
- Check control file: `dpkg -I gitbasher_${VERSION}_all.deb`
- Test installation: `sudo dpkg -i gitbasher_${VERSION}_all.deb`

### Install script fails

- Check that the release and checksums are uploaded to GitHub
- Verify URLs are correct
- Test with `bash -x install.sh` for debugging

## Resources

- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [Debian New Maintainers' Guide](https://www.debian.org/doc/manuals/maint-guide/)
- [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [semantic-release](https://semantic-release.gitbook.io/)
