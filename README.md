# Repository Security Audit

A Hermes skill for evaluating GitHub repositories and npm packages from a **user's perspective** — someone who installs tools but doesn't maintain packages.

## Why This Exists

The TanStack npm supply chain compromise (May 11, 2026) proved that the old security playbook isn't enough. The attacker published 84 malicious versions with valid signatures, using the project's own CI pipeline. No passwords were stolen. The malware activated during `npm install`, harvested credentials, and spread like a worm.

This skill gives you a **staged framework** to check repos and packages before they touch your system.

---

## Two Levels

### Level 1: Surface Check (No Clone, No Extra Tools)
Check stars, commits, install scripts, known CVEs, exotic dependencies — all with just `curl`, `npm`, and `jq`. No download required.

### Level 2: Deep Dive (Requires Security Toolkit)
Run gitleaks, semgrep, osv-scanner, trivy on an isolated `/tmp` clone before migrating to your main system.

**Most threats can be spotted in Level 1.** You rarely need Level 2.

---

## Quick Start

```bash
# Before installing anything
npm info PACKAGE_NAME --json | jq '{scripts: (.scripts | keys), downloads: .downloads["last-week"]}'

# Install safely
npm install --ignore-scripts --allow-git=none

# After installing, check for persistence
ls ~/.local/bin/gh-token-monitor.sh 2>/dev/null
find . -name "router_init.js" -o -name "setup.mjs" 2>/dev/null
```

For full detail, load `references/security-patterns-comprehensive.md`.

---

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Lightweight quick-reference skill |
| `AGENT_ADOPTION.md` | Agent-agnostic adoption guide (any AI agent can use this) |
| `references/security-patterns-comprehensive.md` | Full attack patterns, commands, tooling |
| `AGENTS.md` | Operational guide for agents continuing this work |
| `RESEARCH.md` | Embedded deep research on supply chain threats |
| `scripts/install-security-toolkit.sh` | Installer for Linux / macOS (x86_64, amd64, aarch64, arm64) |
| `scripts/install-security-toolkit.ps1` | Installer for Windows (x64/AMD64) |

---

## Security Toolkit

Five tools, installed via platform-native scripts with checksum verification:

| Tool | What It Does | Stars | Platforms |
|------|-------------|-------|-----------|
| **gitleaks** | Find leaked secrets in Git history | 18k+ | Linux, macOS, Windows; x64 + ARM64 |
| **semgrep** | Static analysis for suspicious code | 15k+ | Any (Python pip) |
| **osv-scanner** | Check dependencies for known CVEs | 6k+ | Linux, macOS, Windows; x64 + ARM64 |
| **trivy** | Comprehensive vuln + secret + config scan | 25k+ | Linux, macOS, Windows; x64 + ARM64 |
| **npq** | Pre-install npm package sanity check | ~500 | Any (Node.js) |

**Install:**
- **Linux / macOS:** `bash scripts/install-security-toolkit.sh`
- **Windows:** `PowerShell -ExecutionPolicy Bypass -File scripts/install-security-toolkit.ps1`

---

## License

MIT. Use it, extend it, share it. The threat landscape changes faster than any one team can track.
