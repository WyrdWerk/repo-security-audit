# Repository Security Audit

A security checklist for anyone who installs open-source tools or npm packages but doesn't maintain them. That was us before we built this.

## Why we made this

In May 2026, the TanStack npm package got compromised. The attacker pushed 84 malicious versions through the project's own CI pipeline. No passwords stolen. The malware simply ran during `npm install`, grabbed credentials, and spread to other packages like a worm.

We realized there wasn't a simple, staged way for a non-coder to check a repo or package before letting it run on their machine. So we built one.

## How it works: two levels

**Level 1 — Surface Check (no tools needed)**

Before you install anything, check it remotely. Stars, commit history, install scripts, known CVEs, exotic dependencies. All you need is `curl`, `npm`, and `jq`. No download. No clone.

Most bad actors show their hand here.

**Level 2 — Deep Dive (install the toolkit)**

If you want code-level certainty before a repo touches your main system, install five security tools and run them against a temporary clone in `/tmp`.

---

## Quick start

```bash
# Before installing anything
npm info PACKAGE_NAME --json | jq '{scripts: (.scripts | keys), downloads: .downloads["last-week"]}'

# Install safely — block hidden code from running
npm install --ignore-scripts --allow-git=none

# After installing, check for persistence
ls ~/.local/bin/gh-token-monitor.sh 2>/dev/null
find . -name "router_init.js" -o -name "setup.mjs" 2>/dev/null
```

For the full command reference, see `references/security-patterns-comprehensive.md`.

---

## Security toolkit

Five tools we audited and installed ourselves. Each has a verified release process and active maintenance.

| Tool | What it does | Stars | Runs on |
|------|-------------|-------|---------|
| **gitleaks** | Scans git history for leaked secrets | 18k+ | Linux, macOS, Windows |
| **semgrep** | Finds suspicious code patterns with static analysis | 15k+ | Any OS (via Python) |
| **osv-scanner** | Checks dependencies against known vulnerability databases | 6k+ | Linux, macOS, Windows |
| **trivy** | Comprehensive scan: vulnerabilities, secrets, config issues | 25k+ | Linux, macOS, Windows |
| **npq** | Audits npm packages before you install them | ~500 | Any OS (via Node.js) |

**Install it:**

- **Linux / macOS** (Intel or Apple Silicon): `bash scripts/install-security-toolkit.sh`
- **Windows** (x64): `PowerShell -ExecutionPolicy Bypass -File scripts/install-security-toolkit.ps1`

Both scripts verify checksums where possible and skip tools that are already installed.

---

## What's in this repo

| File | What it does |
|------|-------------|
| `SKILL.md` | Quick reference for Hermes. Lightweight. Under 6KB. |
| `AGENT_ADOPTION.md` | The full guide — any AI agent can read and follow this, no framework lock-in. |
| `references/security-patterns-comprehensive.md` | Detailed attack patterns, real incidents with dates, commands, and tooling reference. This file grows as new threats emerge. |
| `AGENTS.md` | How we work — voice guidelines, confidence labels, extension rules. |
| `CONCEPT.md` | How this repo evolved from a single panic-driven doc to a structured skill. |
| `RESEARCH.md` | Raw research output (~3,500 words) on npm supply chain threats 2024-2026. |
| `scripts/install-security-toolkit.sh` | Linux / macOS installer. Detects your OS and architecture automatically. |
| `scripts/install-security-toolkit.ps1` | Windows installer. Uses PowerShell-native commands. |

---

## License

MIT. Use it, extend it, share it.
