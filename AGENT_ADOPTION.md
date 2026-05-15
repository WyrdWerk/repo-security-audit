# Agent Adoption Guide — repo-security-audit

> **Purpose:** This is a general-agent-readable version of the repo-security-audit skill. It contains the full quick-reference plus staged invocation strategy so any agent (Droid, Hermes, Claude Code, Cursor, etc.) can follow it without framework-specific syntax.

---

## When to Use This Skill

- Before cloning or installing anything unfamiliar
- After a major supply chain incident (check if the user was affected)
- Weekly system health check for persistence files
- Before running `npm install` on a new project

**Target Audience:** Non-coders who install tools and dependencies but do not maintain packages. All advice is framed from that perspective.

---

## Core Principle: Two Levels, Conditional Deep Dive

| Level | Requires | When to Use |
|-------|----------|-------------|
| **1. Surface Check** | Nothing extra — just `curl`, `npm`, `jq` | Always, before any clone or install |
| **2. Deep Dive** | Security toolkit (`gitleaks`, `semgrep`, `osv-scanner`, `trivy`) | Only if you want certainty before putting a repo on your main system |

**Never skip Level 1.** Most compromises can be spotted without downloading anything. Level 2 is optional — run it when you need full code-level assurance.

---

## Level 1 — Surface Check (Always Available)

No extra tools needed. Just `curl`, `npm`, and `jq`.

### Part A: Before You Install (Remote Recon)

**Goal:** Determine if the repo is worth investigating further.

#### GitHub Health Signals

```bash
curl -s https://api.github.com/repos/OWNER/REPO | jq '{
  stars: .stargazers_count,
  forks: .forks_count,
  updated: .updated_at,
  open_issues: .open_issues_count,
  license: .license.name
}'
```

**Red flags:**
- 0 stars with high forks (bot activity)
- No commits in 6+ months for active tools
- Many open issues with no maintainer replies
- Single maintainer with no backup
- No license file

#### npm Registry Checks (Before Install)

```bash
# Package metadata
npm info PACKAGE_NAME --json | jq '{
  version: .version,
  date: .time[.version],
  downloads: .downloads["last-week"],
  maintainers: .maintainers,
  scripts: (.scripts | keys)
}'

# Check for install scripts (red flag if present)
npm info PACKAGE_NAME --json | jq '.scripts | to_entries[] | select(.key | test("install|prepare|postinstall|preinstall")) | .key'
```

**Red flags:**
- Low weekly downloads (higher typosquatting risk)
- Recent publish with no history
- Install scripts present (especially `postinstall`, `preinstall`)
- Few or unknown maintainers

#### GitHub Advisory Database (Known CVEs)

```bash
curl -s "https://api.github.com/advisories?affected=PACKAGE_NAME" | jq '.[] | {
  cve_id: .cve_id,
  severity: .severity,
  summary: .summary
}' | head -5
```

**What this catches:** Abandoned repos, low-trust packages, install scripts present, known CVEs.

### Part B: Surface Red Flags (Still No Clone)

**Goal:** Spot abuse vectors without downloading anything.

#### Exotic Dependency Detection

```bash
# Check package.json for git URLs, tarball URLs, orphaned GitHub commits
curl -s https://raw.githubusercontent.com/OWNER/REPO/main/package.json | jq '.. | strings | select(test("git\\+ssh|git\\+https|https?://.*\\.tgz|github:.*#"))'
```

**Red flags:**
- `"dependency": "git+https://github.com/attacker/repo"` — bypasses npm registry scanning
- `"dependency": "https://evil.com/package.tgz"` — no provenance, no signature
- `"dependency": "github:org/repo#orphan-commit-hash"` — references orphaned commits not in any branch

#### VS Code Tasks.json Abuse Vector

```bash
curl -s https://raw.githubusercontent.com/OWNER/REPO/main/.vscode/tasks.json | jq '.tasks[].command' 2>/dev/null
```

**Red flag:** Any shell command or script execution in task definitions.

#### AI Agent Injection Files

```bash
# Check for .claude/ injection files
curl -s https://api.github.com/repos/OWNER/REPO/contents/.claude | jq '.[].name' 2>/dev/null

# Check for .cursorrules
curl -s https://raw.githubusercontent.com/OWNER/REPO/main/.cursorrules 2>/dev/null | head -10
```

**Red flag:** Unexpected AI agent configuration files in a project that shouldn't have them.

#### CI Workflow Danger Signals

```bash
# Check for pull_request_target (executes fork code in base context)
curl -s https://raw.githubusercontent.com/OWNER/REPO/main/.github/workflows/ci.yml | grep -E "pull_request_target|id-token: write" 2>/dev/null
```

**Red flags:**
- `pull_request_target` — executes fork code in base context
- `id-token: write` — OIDC token extraction risk if not scoped to exact publish job

#### Forged Commit Identity

```bash
curl -s https://api.github.com/repos/OWNER/REPO/commits?per_page=5 | jq '.[].commit.author | {name, email, date}'
```

**Red flag:** Fabricated identity like `claude <claude@users.noreply.github.com>` or other bot impersonation.

**What this catches:** Exotic deps, VS Code task abuse, AI agent injection, CI misconfigurations, suspicious commit authors.

### Part C: After You Install

```bash
# Check for persistence files (run this after ANY unfamiliar install)
ls ~/.local/bin/gh-token-monitor.sh ~/.config/systemd/user/gh-token-monitor.service ~/Library/LaunchAgents/com.user.gh-token-monitor.plist 2>/dev/null
ls -d .claude/ .vscode/ 2>/dev/null
find . -name "router_init.js" -o -name "tanstack_runner.js" -o -name "setup.mjs" 2>/dev/null

# Check for suspicious patterns in the package
grep -rE "fetch\(|https?://|child_process|spawn|exec\(|process\.env|eval\(" node_modules/PACKAGE_NAME/ 2>/dev/null | head -10

# Run npm audit for known vulnerabilities
npm audit
```

---

## Level 2 — Deep Dive (Requires Security Toolkit)

**Prerequisite:** Run `bash scripts/install-security-toolkit.sh` to install the 5 tools below. These are only needed when you want full code-level assurance before putting a repo on your main system.

### Deep Audit Commands

```bash
# Clone to temp first — NEVER --recursive on untrusted repos
git clone --no-recursive https://github.com/OWNER/REPO /tmp/repo-audit-$RANDOM
cd /tmp/repo-audit-*

# Secret scan — checks entire Git history
gitleaks detect --source .

# Suspicious code patterns — AST analysis, not just text grep
semgrep scan -q -d .

# Known vulnerabilities in dependencies
osv-scanner scan -r .

# Everything-at-once: vulns + secrets + config issues
trivy fs --security-checks vuln,config,secret .
```

**Only after clean results** → migrate to `~/projects/`.

### Which Tool When

| You Want To Know | Level | Tool | Needs Clone? |
|-----------------|-------|------|-------------|
| Is this repo trustworthy at a glance? | 1 | GitHub API + npm info | No |
| Does it have known CVEs? | 1 | GitHub Advisory DB | No |
| Are there hidden install scripts? | 1 | `npm info` scripts field | No |
| Are there exotic dependencies? | 1 | Raw `package.json` curl | No |
| Could VS Code execute malware on open? | 1 | Raw `.vscode/tasks.json` curl | No |
| Is AI agent injection present? | 1 | `.claude/` / `.cursorrules` check | No |
| Are there leaked secrets in Git history? | 2 | gitleaks | Yes |
| Are there suspicious code patterns? | 2 | semgrep | Yes |
| Are dependencies vulnerable? | 2 | osv-scanner | Yes |
| Comprehensive scan everything? | 2 | trivy | Yes |

---

## Safe Installation Practices

### Block ALL Hidden Code During Install

```bash
# npm
npm install --ignore-scripts --allow-git=none

# pnpm
pnpm install --ignore-scripts

# yarn
yarn install --ignore-scripts
```

### Try Once Without Persisting

```bash
npx PACKAGE_NAME@VERSION
```

### Set Cooldown for Fresh Packages (npm >= 11.10.0)

```bash
npm config set min-release-age 7d
```

---

## Post-Install Persistence Check

Run after installing ANY unfamiliar package:

```bash
# Check for persistence files (dead-man's switch, etc.)
ls ~/.local/bin/gh-token-monitor.sh ~/.config/systemd/user/gh-token-monitor.service ~/Library/LaunchAgents/com.user.gh-token-monitor.plist 2>/dev/null
ls -d .claude/ .vscode/ 2>/dev/null
find . -name "router_init.js" -o -name "tanstack_runner.js" -o -name "setup.mjs" 2>/dev/null

# Check for suspicious patterns in the package
grep -rE "fetch\(|https?://|child_process|spawn|exec\(|process\.env|eval\(" node_modules/PACKAGE_NAME/ 2>/dev/null | head -10

# Run npm audit for known vulnerabilities
npm audit
```

**Critical order for dead-man's switch:** Kill persistence files FIRST, then rotate tokens. Revoking first triggers the payload.

---

## Key Attack Patterns (Summary)

| Pattern | What Happens | Defense |
|---------|-------------|---------|
| **Lifecycle scripts** | `postinstall` runs hidden code during `npm install` | `--ignore-scripts` |
| **Typosquatting** | `axois` instead of `axios` | Double-check exact name |
| **Exotic deps** | Package uses `git+https` or tarball URLs | `--allow-git=none` |
| **Dead-man's switch** | Malware wipes home if you revoke stolen token | Kill persistence FIRST, then rotate tokens |
| **Worm propagation** | Malware republishes your packages with same injection | Audit your own npm packages for unexpected versions |
| **AI agent injection** | Malware drops files into `.claude/` or `.vscode/` | Check these directories after installs |
| **MCP server vector** | `npx` resolves latest version each time — compromised between runs | Pin exact versions for MCP tools |
| **Cache poisoning** | Attacker poisons build cache, release workflow restores it | Separate PR and release cache scopes |
| **OIDC extraction** | Malware reads runner memory to extract OIDC tokens | Limit `id-token: write` to exact publish job |
| **Git submodule RCE** (CVE-2024-32002) | Malicious submodules with `post-checkout` hook execute during clone | Never `--recursive` on untrusted repos |
| **Repojacking** | Attacker claims abandoned namespace after owner changes/deletes account | Check commit history for ownership transitions |
| **VS Code tasks.json abuse** | Malicious `.vscode/tasks.json` executes commands on project open | Check `.vscode/tasks.json` before opening in VS Code |
| **Secret leakage** | Credentials accidentally committed to public repos | Rotate any credential that touched a public repo |

---

## Confidence Labels (Mandatory)

When reporting findings:
- **[CONFIRMED]** — You ran the command and saw the output
- **[OBSERVED]** — You see it in the file but haven't tested functionality
- **[UNCERTAIN]** — Pattern matches known attack but could be legitimate
- **[VERIFYING]** — You intend to check but haven't yet

---

## Safety Audit: Five Security Toolkit Tools

The following Stage 1/2 remote recon was performed on the five tools installed by `scripts/install-security-toolkit.sh`:

### gitleaks (gitleaks/gitleaks)
- **Stars:** 26,970 | **License:** MIT | **Active:** Last push 2026-05-13, release v8.30.1 on 2026-03-21
- **Maintainer:** Zachary Rice (zricethezav) — consistent identity across commits and releases
- **Install method:** GitHub release binary + SHA256 checksum verification
- **Stage 2 checks:** No `.vscode/tasks.json` (404), no CI danger signals, no exotic dependencies
- **npm package:** Unrelated old package (v1.0.0 from 2020) — not the actual tool
- **No known CVEs specifically affecting gitleaks found**
- **Verdict:** [CONFIRMED] Safe to install. Well-established open-source secret scanner with verified release process.

### semgrep (semgrep/semgrep)
- **Stars:** 15,145 | **License:** LGPL v2.1 | **Active:** Last push 2026-05-15, release v1.162.0 on 2026-05-07
- **Maintainer:** Semgrep Inc. (semgrep-ci[bot] for releases, human maintainers for code)
- **Install method:** `uv tool install` (isolated) or `pipx install` or `pip3 install --user`
- **Stage 2 checks:** No `.vscode/tasks.json` (404), no CI danger signals, no exotic dependencies
- **npm package:** Unrelated old package (v0.0.1 from 2020) — semgrep is a Python/OCaml tool
- **No known CVEs specifically affecting semgrep found**
- **Verdict:** [CONFIRMED] Safe to install. Major static analysis tool with active development and corporate backing.

### osv-scanner (google/osv-scanner)
- **Stars:** 10,183 | **License:** Apache 2.0 | **Active:** Last push 2026-05-15, release v2.3.8 on 2026-05-08
- **Maintainer:** Google (osv-robot for automated updates, Rex P and others for features)
- **Install method:** `go install` (builds from source) or verified binary + checksum
- **Stage 2 checks:** No `.vscode/tasks.json` (404), CI workflows are standard (checks.yml, codeql-analysis.yml, dependencies.yml), no danger signals
- **No npm package**
- **No known CVEs specifically affecting osv-scanner found**
- **Verdict:** [CONFIRMED] Safe to install. Official Google project for vulnerability scanning.

### trivy (aquasecurity/trivy)
- **Stars:** 35,000 | **License:** Apache 2.0 | **Active:** Last push 2026-05-14, release v0.70.0 on 2026-04-17
- **Maintainer:** Aqua Security (dependabot for deps, Argon-DevOps-Mgt for releases)
- **Install method:** Signed APT repository (GPG key verified, signed-by directive)
- **Stage 2 checks:** No `.vscode/tasks.json` (404), no CI danger signals, no exotic dependencies
- **No npm package**
- **No known CVEs specifically affecting trivy found**
- **Verdict:** [CONFIRMED] Safe to install. Enterprise-grade scanner with signed package distribution.

### npq (lirantal/npq)
- **npm package v3.19.2**, published 2026-04-26 | **Maintainers:** 2 (Liran Tal)
- **Scripts:** `prepare: "husky || true"` (standard dev tooling), `#postinstall` and `#preuninstall` are commented out — **no active install scripts that execute on install**
- **GitHub:** lirantal/npq, last commit 2026-05-14 by Liran Tal
- **Stage 2 checks:** No `.vscode/tasks.json` (404), no CI danger signals
- **No known CVEs specifically affecting npq found**
- **Verdict:** [CONFIRMED] Safe to install. Self-auditing npm package safety tool by established security maintainer. The `prepare` script runs only during development (not on end-user install) and contains only `husky || true`.

---

## Well-Known Security Tooling Repos

| Repo | Stars | What It Does | Install Method |
|------|-------|-------------|--------------|
| [gitleaks](https://github.com/gitleaks/gitleaks) | 18k+ | Secret scanner for repos and CI | GitHub release binary + checksum verify |
| [semgrep](https://github.com/semgrep/semgrep) | 15k+ | Lightweight static analysis | `uv tool install` (isolated) |
| [osv-scanner](https://github.com/google/osv-scanner) | 6k+ | Vulnerability lookup via OSV database | `go install` or binary + checksum |
| [trivy](https://github.com/aquasecurity/trivy) | 25k+ | Config & secret scanner for repos | Signed APT repository |
| [npq](https://github.com/lirantal/npq) | ~500 | Pre-install npm package sanity check | npm global with self-audit |

---

## One-Liner Health Checks

### Pre-Install
```bash
pkg="PACKAGE_NAME"; echo "=== Package: $pkg ==="; npm info "$pkg" --json | jq -r '{version: .version, date: .time[.version], downloads: .downloads["last-week"], maintainers: .maintainers | length, scripts: (.scripts | keys | join(", "))}'; echo "=== Install scripts ==="; npm info "$pkg" --json | jq '.scripts | to_entries[] | select(.key | test("install|prepare")) | .key'
```

### Post-Install
```bash
echo "=== Persistence ==="; ls ~/.local/bin/gh-token-monitor.sh ~/.config/systemd/user/gh-token-monitor.service ~/Library/LaunchAgents/com.user.gh-token-monitor.plist 2>/dev/null; echo "=== Hidden dirs ==="; ls -d .claude .vscode 2>/dev/null; echo "=== Payloads ==="; find . -name "router_init.js" -o -name "tanstack_runner.js" -o -name "setup.mjs" 2>/dev/null
```

---

## Safe Cloning Practices

```bash
# Never clone untrusted repos with --recursive (CVE-2024-32002)
git clone --no-recursive <repository-url>

# Only after inspecting submodules manually:
cd <repo>
git submodule status
git submodule init   # only if you trust them
git submodule update
```

---

## Changelog

- v1.3.0 — Refactored: Split into Level 1 (Surface Check, always available) and Level 2 (Deep Dive, requires security toolkit install). Install script bugs fixed (local vars, checksum URLs, grep mismatch).
- v1.2.0 — Added: Agent-agnostic adoption guide (`AGENT_ADOPTION.md`) with Stage 1/2 safety audit for all five toolkit tools.
- v1.1.0 — Added: CVE-2024-32002, repojacking, VS Code tasks.json abuse, secret leakage stats, prompt injection via comments. Added tools: gitleaks, semgrep, osv-scanner, trivy, TruffleHog.
- v1.0.0 — Initial comprehensive reference covering TanStack, Axios, chalk/debug patterns.
