# Repository Security Audit

A Hermes skill for evaluating GitHub repositories and npm packages from a **user's perspective** — someone who installs tools but doesn't maintain packages.

## Why This Exists

The TanStack npm supply chain compromise (May 11, 2026) proved that the old security playbook isn't enough. The attacker published 84 malicious versions with valid signatures, using the project's own CI pipeline. No passwords were stolen. The malware activated during `npm install`, harvested credentials, and spread like a worm.

This skill gives you a **staged framework** to check repos and packages before they touch your system.

---

## The Three Stages

### Stage 1: Remote Recon (No Clone)
Check stars, commits, install scripts, known CVEs — all without downloading anything.

### Stage 2: Surface Red Flags (Still No Clone)
Spot exotic dependencies, VS Code task abuse, AI agent injection — via HTTP calls only.

### Stage 3: Deep Audit (Clone to `/tmp` First)
Run gitleaks, semgrep, osv-scanner, trivy on an isolated copy before migrating to your main system.

**Most threats can be spotted in Stage 1.** You rarely need Stage 3.

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
| `references/security-patterns-comprehensive.md` | Full attack patterns, commands, tooling |
| `AGENTS.md` | Operational guide for agents continuing this work |
| `CONVERSATION.md` | Session context and decisions (historical) |
| `RESEARCH.md` | Embedded deep research on supply chain threats |
| `scripts/install-security-toolkit.sh` | Installer for gitleaks, semgrep, osv-scanner, trivy, npq |

---

## Security Toolkit

Five tools, all installed via a single script with checksum verification:

| Tool | What It Does | Stars |
|------|-------------|-------|
| **gitleaks** | Find leaked secrets in Git history | 18k+ |
| **semgrep** | Static analysis for suspicious code | 15k+ |
| **osv-scanner** | Check dependencies for known CVEs | 6k+ |
| **trivy** | Comprehensive vuln + secret + config scan | 25k+ |
| **npq** | Pre-install npm package sanity check | ~500 |

```bash
bash scripts/install-security-toolkit.sh
```

---

## License

MIT. Use it, extend it, share it. The threat landscape changes faster than any one team can track.
