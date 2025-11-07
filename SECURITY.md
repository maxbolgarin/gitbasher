# Security Policy

## Overview

**gitbasher** is committed to maintaining the security of our users' development environments. This document outlines our security practices, known considerations, and how to report vulnerabilities.

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 3.x     | :white_check_mark: |
| < 3.0   | :x:                |

**Recommendation**: Always use the latest version from the main branch for the most up-to-date security fixes.

## Security Considerations

### 1. Command Injection Prevention

**gitbasher** handles user input carefully to prevent command injection attacks:

#### What We Do
- **Input Sanitization**: All user inputs are sanitized before use in shell commands
- **No eval Usage**: We avoid `eval` with user-controlled input
- **Quoted Variables**: All variables are properly quoted in commands
- **Parameterized Commands**: Use safe command construction methods

#### Example Protection
```bash
# User input is sanitized
user_input='$(malicious command)'
sanitized=$(sanitize "$user_input")  # Removes dangerous characters

# Variables are properly quoted
git commit -m "$sanitized"  # Safe
```

#### What You Should Do
- Keep gitbasher updated for latest security fixes
- Review any custom scripts or hooks you create
- Be cautious when using gitbasher in automated systems

### 2. API Key Security

**gitbasher** supports AI features that require API keys:

#### Storage
- API keys are stored in git config
- **Local config**: Only accessible in current repository (`.git/config`)
- **Global config**: Accessible system-wide (`~/.gitconfig`)

#### Best Practices
1. **Use Local Storage**: Prefer local over global for repository-specific keys
   ```bash
   gitb cfg ai  # Choose "local" when prompted
   ```

2. **Use Environment Variables**: For CI/CD environments
   ```bash
   export GITBASHER_AI_KEY="your-key-here"
   ```

3. **Rotate Keys Regularly**: Especially if repository is shared
   ```bash
   gitb cfg ai  # Update with new key
   ```

4. **Never Commit Keys**: Ensure `.gitconfig` is not tracked
   ```bash
   # .gitignore
   .gitconfig
   ```

5. **Use API Key Restrictions**: Configure key restrictions in [Google AI Studio](https://aistudio.google.com/)
   - Limit by IP address
   - Limit by API
   - Set usage quotas

#### Removing Keys
```bash
# Remove global AI key
gitb cfg delete ai

# Or manually
git config --global --unset gitbasher.ai

# Remove local AI key
git config --local --unset gitbasher.ai
```

### 3. Git Hook Security

Git hooks can execute arbitrary code. **gitbasher** provides hook management:

#### Risks
- Hooks run with your user permissions
- Malicious hooks can execute harmful commands
- Hooks from untrusted sources are dangerous

#### Safe Practices
1. **Review Before Install**: Always review hook contents
   ```bash
   gitb hook show <hook-name>  # View hook before enabling
   ```

2. **Use Templates**: Use gitbasher's built-in templates
   ```bash
   gitb hook create  # Use trusted templates
   ```

3. **Test Safely**: Test hooks before committing
   ```bash
   gitb hook test <hook-name>
   ```

4. **Regular Audits**: Review active hooks periodically
   ```bash
   gitb hook list
   ```

### 4. Proxy Configuration

When using HTTP proxies for AI features:

#### Security Notes
- Proxy credentials may be logged
- Use HTTPS proxies when possible
- Avoid untrusted proxy servers

#### Safe Configuration
```bash
# Use environment variable (temporary)
export HTTPS_PROXY="https://proxy.example.com:8080"
gitb c ai

# Or configure in gitbasher (persistent)
gitb cfg proxy
```

### 5. Repository Access

**gitbasher** operates on your git repositories:

#### Permissions
- Requires read/write access to git repository
- Uses your git credentials for remote operations
- Respects git authentication (SSH keys, HTTPS tokens)

#### Safe Practices
1. **Use SSH Keys**: More secure than HTTPS tokens
   ```bash
   # Set up SSH key authentication
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```

2. **Protect Credentials**: Use credential helpers
   ```bash
   git config --global credential.helper store
   ```

3. **Verify Remotes**: Check remote URLs before pushing
   ```bash
   gitb st  # Shows remote information
   git remote -v
   ```

### 6. Temporary Files

**gitbasher** creates temporary files for operations:

#### What We Do
- Use secure temporary directories
- Clean up temporary files after use
- Set restrictive permissions (600)

#### Locations
- `/tmp/gitb-*`: Temporary operation files
- `~/.gitbasher/`: Configuration cache

## Known Limitations

1. **Bash Security Model**: Inherits bash's security characteristics
2. **Git Credential Access**: Has access to your git credentials
3. **File System Access**: Can read/write repository files
4. **Network Access**: Makes API calls for AI features

## Reporting a Vulnerability

### How to Report

If you discover a security vulnerability, please report it responsibly:

1. **Do NOT open a public issue**
2. **Contact privately**:
   - **Email**: maxbolgarin@gmail.com
   - **Telegram**: [@maxbolgarin](https://t.me/maxbolgarin)

3. **Include in your report**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)
   - Your contact information

### What to Expect

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 1 week
- **Status Updates**: Every 2 weeks
- **Fix Timeline**: Depends on severity
  - Critical: 1-7 days
  - High: 1-2 weeks
  - Medium: 2-4 weeks
  - Low: Best effort

### Disclosure Policy

1. **Coordinated Disclosure**: We prefer coordinated disclosure
2. **Fix First**: We'll develop and test a fix
3. **Public Disclosure**: After fix is released
4. **Credit**: We'll credit reporters (unless they prefer anonymity)

## Security Best Practices for Users

### Installation

```bash
# Download from official source only
curl -SL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/dist/gitb -o /tmp/gitb

# Review the script before installing
less /tmp/gitb

# Install
sudo mv /tmp/gitb /usr/local/bin/gitb
sudo chmod +x /usr/local/bin/gitb
```

### Regular Updates

```bash
# Update to latest version
GITB_PATH=/usr/local/bin/gitb && \
curl -SL https://raw.githubusercontent.com/maxbolgarin/gitbasher/main/dist/gitb -o $GITB_PATH && \
chmod +x $GITB_PATH

# Check version
head -n 5 /usr/local/bin/gitb
```

### Secure Configuration

```bash
# Use local configuration for API keys
gitb cfg ai  # Choose "local"

# Review configuration
gitb cfg

# Set restrictive permissions on config
chmod 600 ~/.gitconfig
```

### Audit Your Setup

```bash
# Check active hooks
gitb hook list

# Review git configuration
git config --list --show-origin

# Check remote URLs
git remote -v

# Review recent git operations
gitb reflog
```

## Security Checklist

- [ ] Using latest version of gitbasher
- [ ] API keys stored securely (local config preferred)
- [ ] Git hooks reviewed and trusted
- [ ] SSH keys used for authentication
- [ ] Regular security updates applied
- [ ] Proxy configuration secure (if used)
- [ ] No sensitive data in git config
- [ ] Git credentials properly managed
- [ ] Regular audits of repository access

## Additional Resources

- [OWASP Command Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/OS_Command_Injection_Defense_Cheat_Sheet.html)
- [Git Security](https://git-scm.com/book/en/v2/Git-Tools-Credential-Storage)
- [Bash Security](https://mywiki.wooledge.org/BashGuide/Practices#Security)
- [GitHub Security Best Practices](https://docs.github.com/en/code-security)

## Security Updates

Security updates are announced via:
- GitHub Releases
- Repository README
- Security advisories (for critical issues)

Subscribe to releases: Watch repository → Custom → Releases

## License

This security policy is part of the gitbasher project and is covered by the MIT License.

---

**Security is a shared responsibility. If you see something, say something.**

Last Updated: 2025-11-07
