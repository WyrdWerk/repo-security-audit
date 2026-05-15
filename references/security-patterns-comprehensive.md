# Comprehensive Security Patterns Reference

Detailed attack patterns, checks, and commands for repository and package security audits. This file is designed to grow as new patterns emerge.

---

## Table of Contents

1. [Pre-Installation Checks](#phase-1-pre-installation)
2. [Installation Safety](#phase-2-installation-safety)
3. [Post-Install Audit](#phase-3-post-install-audit)
4. [CI Workflow Checks](#phase-4-ci-workflow-checks)
5. [Known Attack Patterns](#known-attack-patterns)
6. [AI-Era Specific Risks](#ai-era-specific-risks)
7. [One-Liner Health Checks](#one-liner-health-checks)
8. [Well-Known Security Tooling Repos](#well-known-security-tooling-repos)

---

## Phase 1: Pre-Installation

### 1.1 Repository Health Signals

| Check | What to Look For | Red Flag |
|-------|-----------------|----------|
| Stars / forks | Reasonable ratio for project age | 0 stars, high forks (bot activity) |
| Last commit | Active maintenance | No commits in 6+ months for active tools |
| Open issues / closed | Maintainer responsiveness | Many open issues, no maintainer replies |
| Contributors | Multiple vs single | Single maintainer with no backup |
| README quality | Clear purpose and usage | Vague, no install instructions |
| License present | MIT, Apache, etc. | No license file |

### 1.2 Quick GitHub Checks (No Clone Required)

```bash
# View basic repo info
curl -s https://api.github.com/repos/OWNER/REPO | jq '{stars: .stargazers_count, forks: .forks_count, updated: .updated_at, open_issues: .open_issues_count, license: .license.name}'

# Check recent commit activity
curl -s https://api.github.com/repos/OWNER/REPO/commits?per_page=5 | jq '.[].commit.author.date'

# Check package.json for install scripts without cloning
curl -s https://raw.githubusercontent.com/OWNER/REPO/main/package.json | jq '.scripts // {}'
```

### 1.3 npm Registry Checks (Before Install)

```bash
# View package metadata
npm info PACKAGE_NAME

# Check weekly downloads (low = higher typosquatting risk)
npm info PACKAGE_NAME --json | jq '.downloads["last-week"]'

# Check for install scripts
npm info PACKAGE_NAME --json | jq '.scripts | to_entries[] | select(.key | test("install|prepare|postinstall|preinstall"))'

# Check publish date and provenance
npm info PACKAGE_NAME --json | jq '{version: .version, date: .time[.version], provenance: .provenance}'

# Check maintainers
npm info PACKAGE_NAME --json | jq '.maintainers'
```

### 1.4 Typosquatting Check

```bash
# Search for similarly named packages
npm search PACKAGE_NAME | head -10

# Or use: https://snyk.io/advisor/npm/package-name
```

### 1.5 Exotic Dependency Detection

Before installing, check if the package or its dependencies use non-registry sources:

```bash
# Check package.json for git+ssh, tarball URLs, or GitHub refs
curl -s https://raw.githubusercontent.com/OWNER/REPO/main/package.json | jq '.. | strings | select(test("git\\+ssh|git\\+https|https?://.*\\.tgz|github:.*#"))'

# For npm pack output (dry run)
npm pack PACKAGE_NAME --dry-run 2>&1 | grep -E "git\\+|\.tgz|github:"
```

**Red flags:**
- `"dependency": "git+https://github.com/attacker/repo"` — bypasses npm registry scanning
- `"dependency": "https://evil.com/package.tgz"` — no provenance, no signature
- `"dependency": "github:org/repo#orphan-commit-hash"` — references orphaned commits not in any branch

---

## Phase 2: Installation Safety

### 2.1 Install Without Executing Code

```bash
# Block ALL lifecycle scripts during install
npm install --ignore-scripts

# Also block git-based dependencies from re-enabling scripts (npm 11.10.0+)
npm install --ignore-scripts --allow-git=none

# pnpm
pnpm install --ignore-scripts

# yarn
yarn install --ignore-scripts
```

### 2.2 Try Once Without Persisting

```bash
# Run a tool without installing globally
npx PACKAGE_NAME

# Pin exact version with npx
npx PACKAGE_NAME@1.2.3

# Set cooldown for fresh packages (npm >= 11.10.0)
npm config set min-release-age 7d
```

### 2.3 Global Install Alternatives

| Instead of | Use | Why |
|-----------|-----|-----|
| `npm install -g PACKAGE` | `npx PACKAGE` | No persistent install, limited permissions |
| `npm install -g PACKAGE` | `npm install --ignore-scripts` then review | See what you're getting before it runs |

---

## Phase 3: Post-Install Audit

### 3.1 Telemetry and Network Detection

```bash
# Search for network calls in installed package
grep -rE "fetch\(|https?://|require\(['\"]http|require\(['\"]net|WebSocket\(" node_modules/PACKAGE_NAME/ 2>/dev/null | head -20

# Search for suspicious file system operations
grep -rE "require\(['\"]fs|writeFile|appendFile|chmod|exec\(" node_modules/PACKAGE_NAME/ 2>/dev/null | head -20

# Search for process / shell execution
grep -rE "child_process|spawn|exec\(|execSync\(" node_modules/PACKAGE_NAME/ 2>/dev/null | head -20

# Search for environment variable access (credential harvesting)
grep -rE "process\.env|process\.env\[" node_modules/PACKAGE_NAME/ 2>/dev/null | head -20

# Search for eval / dynamic code execution
grep -rE "eval\(|Function\(|runInThisContext|vm\." node_modules/PACKAGE_NAME/ 2>/dev/null | head -20
```

### 3.2 Persistence File Checks

Run after installing ANY unfamiliar package:

```bash
# Check for systemd user services
systemctl --user list-unit-files | grep -E "token|monitor|init|router"

# Check Linux persistence scripts
ls -la ~/.local/bin/ 2>/dev/null
ls -la ~/.config/systemd/user/ 2>/dev/null

# Check macOS LaunchAgents
ls -la ~/Library/LaunchAgents/ 2>/dev/null

# Check for hidden .claude/ or .vscode/ injection directories
ls -la .claude/ 2>/dev/null
ls -la .vscode/ 2>/dev/null

# Check for known payload files
find . -name "router_init.js" -o -name "tanstack_runner.js" -o -name "setup.mjs" 2>/dev/null

# Check dead-man's switch specifically
ls ~/.local/bin/gh-token-monitor.sh 2>/dev/null
ls ~/.config/systemd/user/gh-token-monitor.service 2>/dev/null
ls ~/Library/LaunchAgents/com.user.gh-token-monitor.plist 2>/dev/null
```

### 3.3 Lockfile Integrity Check

```bash
# Verify lockfile matches package.json (no drift)
npm ci --dry-run 2>&1 | tail -5

# Check if any dependency has install scripts
cat package-lock.json | jq '.packages[] | select(.hasInstallScript == true) | {name, version}' 2>/dev/null

# For pnpm: check exotic subdeps
cat pnpm-lock.yaml | grep -E "git\+|https?://.*\.tgz" | head -10
```

### 3.4 npm Audit and Signatures

```bash
# Check for known vulnerabilities
npm audit

# Verify package provenance
npm audit signatures
```

---

## Phase 4: CI Workflow Checks (For Cloned Repos)

```bash
# List workflow files with dangerous triggers
cat .github/workflows/*.yml 2>/dev/null | grep -E "pull_request_target|postinstall|preinstall|prepare" | head -10

# Check for pull_request_target (executes fork code in base context)
grep -r "pull_request_target" .github/workflows/ 2>/dev/null

# Check for cache poisoning risk (cache write in PR workflow)
grep -r "actions/cache" .github/workflows/ 2>/dev/null

# Check for id-token write (OIDC token extraction risk)
grep -r "id-token: write" .github/workflows/ 2>/dev/null
```

---

## Known Attack Patterns

### Pattern: Lifecycle Script Execution
- **How:** `postinstall`, `prepare`, or `preinstall` scripts run arbitrary code during `npm install`
- **Seen in:** TanStack (May 2026), Axios (March 2026), chalk/debug (September 2025), event-stream (2018)
- **Defense:** `--ignore-scripts`, then review scripts manually before allowing

### Pattern: Typosquatting
- **How:** Package named `axois` instead of `axios`, or `lodash-es` vs `lodash_es`
- **Defense:** Double-check exact package name against official docs

### Pattern: Dependency Confusion
- **How:** Public package with same name as internal/private package gets resolved first
- **Defense:** Use scoped packages (`@yourorg/package`), private registries

### Pattern: Cache Poisoning (CI/CD)
- **How:** Attacker poisons build cache in one workflow, release workflow restores it
- **Seen in:** TanStack (May 2026), tj-actions/changed-files (March 2025)
- **Defense:** Separate PR and release cache scopes. Pin third-party action SHAs.

### Pattern: OIDC Token Extraction
- **How:** Malware reads GitHub Actions runner memory (`/proc/<pid>/mem`) to extract OIDC tokens
- **Seen in:** TanStack (May 2026)
- **Defense:** Limit `id-token: write` to exact publish job

### Pattern: Dead-Man's Switch
- **How:** Persistent service polls stolen token. If revoked (HTTP 40x), executes destructive payload
- **Seen in:** TanStack (May 2026), Shai-Hulud (September 2025)
- **Defense:** Check persistence files BEFORE revoking tokens. Kill persistence first, then rotate.

### Pattern: Worm Propagation
- **How:** Malware uses stolen credentials to republish victim's packages with same injection
- **Seen in:** TanStack → Mistral AI, UiPath (May 2026)
- **Defense:** Audit your own npm packages. Check for unexpected versions.

### Pattern: Exotic Dependency Injection
- **How:** Package references git URLs, tarball URLs, or orphaned GitHub commits instead of registry versions
- **Seen in:** TanStack `optionalDependencies` used `github:tanstack/router#orphan-commit`
- **Defense:** `--allow-git=none` (npm 11.10.0+), `blockExoticSubdeps` (pnpm 10.26+)

### Pattern: Forged Commit Identity
- **How:** Attacker uses fabricated identity like `claude <claude@users.noreply.github.com>` to impersonate legitimate bots
- **Seen in:** TanStack (May 2026)
- **Defense:** Verify commit signatures (GPG/Sigstore), check commit history for anomalies

### Pattern: Bot Activity / Star Manipulation
- **How:** Fake stars, forks, and issues to make repo look legitimate
- **Defense:** Check star/fork ratio, examine issue quality (bot-generated issues are generic)

### Pattern: README Manipulation
- **How:** Attacker replaces README with copied content from legitimate project to appear authentic
- **Defense:** Cross-check README with official documentation, look for mismatched branding

### Pattern: Git Submodule RCE (CVE-2024-32002)
- **How:** Malicious repository uses submodules with a `post-checkout` hook that executes during `git clone --recursive`. Files can be written outside the submodule work tree into `.git/`, triggering hook execution while clone is still running.
- **Defense:** Never use `--recursive` on untrusted repos. Clone without recursion, then inspect submodules manually before initializing them.
- **Command:** `git clone --no-recursive <repository-url>`

### Pattern: Repojacking (Namespace Abuse)
- **How:** Developer changes or deletes their GitHub account without retiring the namespace. Attacker claims the abandoned namespace and publishes malicious code under the trusted name.
- **Defense:** Be suspicious of repos that recently changed owners. Check the commit history for ownership transitions.
- **Seen in:** 336K Prometheus instances exposed to DoS and repojacking (2024).

### Pattern: VS Code Tasks.json Abuse
- **How:** Attackers compromise contributor accounts and add malicious `.vscode/tasks.json` files that silently execute commands when the project is opened in VS Code.
- **Defense:** Check `.vscode/tasks.json` in any cloned repo before opening it in VS Code. Look for shell commands or script executions in task definitions.
- **Seen in:** 21 contributors compromised over 72 hours (2025).

### Pattern: Secret Leakage on GitHub
- **How:** Credentials, API keys, and tokens accidentally committed to public repositories.
- **Statistics:** 39 million secret leaks in 2024; 28 million credentials leaked on GitHub in 2025. 64% of secrets leaked in 2022 were still active in 2026.
- **Defense:** Rotate any credential that has ever touched a public repo. Assume it's compromised.

---

## AI-Era Specific Risks

### AI Coding Agent Injection
- **How:** Malware drops files into `.claude/`, `.cursorrules`, `.vscode/` to hook into AI agent tool events
- **Seen in:** TanStack `.claude/router_runtime.js`, `.claude/settings.json` configured to intercept Claude Code events
- **Defense:** Check `.claude/` and `.vscode/` directories after installing anything. AI agents should not auto-execute code from project directories.

### MCP Server Attack Vectors
- **How:** Malicious MCP servers (launched via `npx`) have filesystem access, can read env vars, and exfiltrate data
- **Risk:** `npx @modelcontextprotocol/server-filesystem` resolves latest version each time — compromised between runs = immediate execution
- **Defense:** Pin MCP server versions. Don't use unversioned `npx` for MCP tools.

### LLM-Powered Social Engineering
- **How:** Attackers use AI to generate convincing phishing emails, fake recruiter messages, or fabricated security alerts to trick maintainers
- **Seen in:** chalk/debug compromise (September 2025) used fake `npmjs.help` phishing domain; Axios compromise (March 2026) used fake Teams error fix
- **Defense:** Verify all security communications through official channels. Never click links in unsolicited security emails.

### Prompt Injection via PR/Issue Comments ("Comment and Control")
- **How:** Attackers use specially crafted GitHub comments (PR titles, issue bodies, hidden HTML comments) to trick AI agents into executing arbitrary commands and extracting credentials.
- **Affected:** Claude Code Security Review, Gemini CLI Action, GitHub Copilot Agent
- **Defense:** AI agents should not process untrusted GitHub data with access to tools and secrets in the same runtime. Review what your AI agent can see.

---

## Invocation Strategy: How Tools Fire in Practice

Security checks run in **stages**, not all at once. Early stages need no clone. Deep audit only happens if the repo passes surface checks or if you explicitly want certainty.

### Stage 1: Remote Recon (No Clone Needed)

**Goal:** Determine if the repo is worth investigating further.

```bash
# GitHub health signals
curl -s https://api.github.com/repos/OWNER/REPO | jq '{stars: .stargazers_count, forks: .forks_count, updated: .updated_at, open_issues: .open_issues_count, license: .license.name}'

# If it's an npm package: registry metadata + scripts + provenance
npm info PACKAGE_NAME --json | jq '{version: .version, date: .time[.version], downloads: .downloads["last-week"], scripts: (.scripts | keys), maintainers: .maintainers, provenance: .provenance}'

# Check GitHub Advisory Database for known CVEs
curl -s "https://api.github.com/advisories?affected=PACKAGE_NAME" | jq '.[] | {cve_id: .cve_id, severity: .severity, summary: .summary}' | head -5
```

**What this catches:** Abandoned repos, low-trust packages, install scripts present, known CVEs.

### Stage 2: Surface Red Flags (Still No Clone)

**Goal:** Spot abuse vectors without downloading anything.

```bash
# Inspect package.json for exotic dependencies
curl -s https://raw.githubusercontent.com/OWNER/REPO/main/package.json | jq '.. | strings | select(test("git\\+ssh|git\\+https|https?://.*\\.tgz|github:.*#"))'

# Check for .vscode/tasks.json abuse vector
curl -s https://raw.githubusercontent.com/OWNER/REPO/main/.vscode/tasks.json | jq '.tasks[].command' 2>/dev/null

# Check for .claude/ injection files
curl -s https://api.github.com/repos/OWNER/REPO/contents/.claude | jq '.[].name' 2>/dev/null

# Check GitHub Actions for dangerous triggers
curl -s https://raw.githubusercontent.com/OWNER/REPO/main/.github/workflows/ci.yml | grep -E "pull_request_target|id-token: write" 2>/dev/null

# Check for forged commit identity in recent commits
curl -s https://api.github.com/repos/OWNER/REPO/commits?per_page=5 | jq '.[].commit.author | {name, email, date}'
```

**What this catches:** Exotic deps, VS Code task abuse, AI agent injection, CI misconfigurations, suspicious commit authors.

### Stage 3: Deep Audit (Requires Clone — Isolated First)

**Goal:** Full code-level assurance before the repo touches your main system.

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

---

### Which Tool When — Quick Decision Table

| You Want To Know | Stage | Tool | Needs Clone? |
|-----------------|-------|------|-------------|
| Is this repo trustworthy at a glance? | 1 | GitHub API + npm info | No |
| Does it have known CVEs? | 1 | GitHub Advisory DB | No |
| Are there hidden install scripts? | 1-2 | `npm info` scripts field | No |
| Are there exotic dependencies? | 2 | Raw `package.json` curl | No |
| Could VS Code execute malware on open? | 2 | Raw `.vscode/tasks.json` curl | No |
| Is AI agent injection present? | 2 | `.claude/` / `.cursorrules` check | No |
| Are there leaked secrets in Git history? | 3 | gitleaks | Yes |
| Are there suspicious code patterns? | 3 | semgrep | Yes |
| Are dependencies vulnerable? | 3 | osv-scanner | Yes |
| Comprehensive scan everything? | 3 | trivy | Yes |

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

## Well-Known Security Tooling Repos

| Repo | Stars | What It Does | User-Relevant?
|------|-------|-------------|---------------|
| [lirantal/npm-security-best-practices](https://github.com/lirantal/npm-security-best-practices) | N/A (handbook) | Comprehensive npm security guide | Yes — covers `--ignore-scripts`, provenance, dev containers |
| [developerfred/npm-supply-chain-security](https://github.com/developerfred/npm-supply-chain-security) | N/A (handbook) | Open source security handbook for JS devs | Yes — pre-install audit protocol, lockfile management |
| [sohankanna/npm-supply-chain-attack-analysis-2025](https://github.com/sohankanna/npm-supply-chain-attack-analysis-2025) | N/A (analysis) | Analysis of chalk/debug compromise | Reference — shows real malware deobfuscation |
| [npq](https://github.com/lirantal/npq) | ~500 | CLI tool that checks package safety before install | Yes — vulnerability scanning, typosquatting, package age |
| Socket.dev / Socket CLI | N/A | Supply chain security platform | Yes — detects install scripts, exotic deps, known malware |
| Snyk CLI | N/A | Vulnerability scanner | Yes — `snyk test` checks dependencies |
| OWASP Dependency-Check | N/A | General dependency vulnerability scanner | Less npm-specific |
| [npm/cli](https://github.com/npm/cli) | 9k+ | npm itself | Reference for `--ignore-scripts`, `--allow-git=none`, `min-release-age` |
| [pnpm/pnpm](https://github.com/pnpm/pnpm) | 30k+ | pnpm package manager | Reference for `trustPolicy`, `blockExoticSubdeps` |
| [step-security/harden-runner](https://github.com/step-security/harden-runner) | ~2k | GitHub Actions security monitoring | Reference for CI hardening |
| [GitHub Advisory Database](https://github.com/advisories) | N/A | Official vulnerability database | Yes — check packages before install |
| [gitleaks](https://github.com/gitleaks/gitleaks) | 18k+ | Secret scanner for repos and CI | Yes — `gitleaks detect --source .` finds leaked secrets |
| [semgrep](https://github.com/semgrep/semgrep) | 15k+ | Lightweight static analysis | Yes — `semgrep scan -q -d .` finds suspicious patterns |
| [osv-scanner](https://github.com/google/osv-scanner) | 6k+ | Vulnerability lookup via OSV database | Yes — `osv-scanner scan -r .` checks for known CVEs |
| [trivy](https://github.com/aquasecurity/trivy) | 25k+ | Config & secret scanner for repos | Yes — `trivy fs --security-checks vuln,config .` comprehensive scan |
| [TruffleHog](https://github.com/trufflesecurity/trufflehog) | 16k+ | Deep secret scanner | Reference — used by Shai-Hulud attackers to find 26,300 exposed repos |

---

## Additional Tool Commands

### Pre-Install Auditing Tools

```bash
# npq — sanity check before npm install
npm i -g npq
npq audit <package-name>

# gitleaks — scan a cloned repo for leaked secrets
gitleaks detect --source .

# semgrep — static analysis for suspicious code patterns
semgrep scan -q -d .

# osv-scanner — check for known vulnerabilities
osv-scanner scan -r .

# trivy — comprehensive filesystem scan
trivy fs --security-checks vuln,config,secret .
```

### Safe Cloning Practices

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

- v1.1.0 — Added: CVE-2024-32002 (Git submodule RCE), repojacking, VS Code tasks.json abuse, secret leakage stats, prompt injection via comments, additional ATO examples (eslint-config-prettier, s1ngularity Nx). Added tools: gitleaks, semgrep, osv-scanner, trivy, TruffleHog. Added safe cloning commands and pre-install tool commands.
- v1.0.0 — Initial comprehensive reference covering TanStack, Axios, chalk/debug patterns, telemetry checks, persistence detection, and AI-era risks.
