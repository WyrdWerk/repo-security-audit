---
timestamp: "2026-05-15T10:16:37+05:30"
agent_id: "hermes"
agent_name: "Hermes Agent"
session_id: ""
user: "yash"
duration_minutes: 120
topics: ["tanstack", "npm-supply-chain", "cybersecurity", "repo-security-audit", "linkedin-content", "system-security-check", "skill-development"]
related_repos: ["WyrdWerk/agentic-memory-hub"]
related_sessions: ["20260510-172922-hermes"]
artifacts: ["parallel-research-npm-supply-chain-2024-2026"]
learnings: [
  "Security audit skills should split into lightweight SKILL.md + comprehensive references/ file",
  "Install commands for security tools must themselves be audited with the same staged framework",
  "LinkedIn posts from non-coder perspective need self-deprecating vulnerability, not expert authority",
  "User prefers Stage 1-2 remote recon before clone when analyzing repositories",
  "Dead-man's switch persistence files must be killed BEFORE token revocation"
]
---

## Context

User asked about the recent TanStack npm supply chain compromise (May 11, 2026). Session evolved from pure research explanation into a multi-faceted workstream: personal system security audit, LinkedIn post creation (with anbeeld-writing + humanizer-pass), a new repo-security-audit skill creation with deep research augmentation, a security toolkit install script, and a system update check.

## Key Discussion Points

### 1. TanStack NPM Supply Chain Compromise Analysis
- **CVE-2026-45321** / **GHSA-g7cv-rxg3-hmpx** — 84 malicious versions across 42 @tanstack/* packages published May 11, 2026, 19:20-19:26 UTC (~00:50-00:56 IST May 12)
- **Attack chain:** Poisoned PR via `pull_request_target` → GitHub Actions cache poisoning → release workflow restores poisoned cache → memory extraction of OIDC token from `Runner.Worker` via `/proc/<pid>/mem` → direct POST to registry.npmjs.org
- **Malware behavior:** Credential harvesting (AWS/GCP/K8s/Vault/GitHub/SSH/npmrc), worm propagation to other packages, dead-man's switch (wipes home directory if token revoked)
- **Valid signatures:** Packages carried valid SLSA/Sigstore provenance attestations because published from legitimate GitHub Actions runner
- **Worm spread:** Hit Mistral AI, UiPath, and 170+ other packages within hours
- **Detection:** Malware drops persistent files: `~/.local/bin/gh-token-monitor.sh`, `~/.config/systemd/user/gh-token-monitor.service` (Linux), `~/Library/LaunchAgents/com.user.gh-token-monitor.plist` (macOS), `.claude/router_runtime.js`, `.vscode/setup.mjs`
- **Critical order:** Kill persistence files FIRST, THEN revoke/rotate tokens. Revoking first triggers the dead-man's switch.

### 2. Personal System Security Audit
- User ran checks on their Yoga Pro 7 (Ubuntu 24.04, aarch64):
  - `ls ~/.local/bin/gh-token-monitor.sh` → not found
  - `ls ~/.config/systemd/user/gh-token-monitor.service` → not found
  - `systemctl --user status gh-token-monitor.service` → not found
  - `find /home/yash/projects` for payload files → none found
  - Shell history: zero npm/pnpm/yarn activity around May 12 00:50 IST
  - npm logs: no entries from May 11-12
- **Verdict:** Device was not affected by this campaign. No tokens need rotation.

### 3. LinkedIn Post Creation
- User wanted a post in their voice: non-coder, translator/bridge between technical and general audience
- **Process:** Multiple drafts → anbeeld-writing structural pass → humanizer-pass voice injection
- **Final draft (202 words):**
  > I just read about the TanStack supply chain attack. I had to ask my AI setup to explain the postmortem because I didn't fully grasp it myself.
  > I download open source repos constantly and ask my setup to flag telemetry before installing. But that habit isn't nearly enough.
  > TanStack is a set of tools millions of developers depend on. On May 11th, someone published malicious versions. Not by stealing a password. They tricked TanStack's own release system into publishing malware for them. The packages even had valid signatures.
  > The malware activates on install, steals credentials, and spreads like a worm. It drops a dead-man's switch: if you revoke the stolen token, it wipes your home directory.
  > I'm checking my system for gh-token-monitor and router_init.js. But honestly? What else am I not aware of?
  > For someone like me who installs things:
  > - Using `--ignore-scripts` on unfamiliar repos. It blocks the hidden code that triggered this without breaking the tool.
  > - Avoiding global installs. `npx` lets me try something once without leaving it on my system.
  > - Checking what I install and when. If something looks suspicious, I pause before hitting `npm install`.
  > And I'm exploring an isolated dev sandbox. It boots like a full Linux system but wipes clean in seconds. Projects mount in, tools work, anything installed stays trapped inside.
  > The old security playbook just got weaponized. Time to rebuild it.

### 4. repo-security-audit Skill Creation
- **Architecture:** Lightweight `SKILL.md` (~3KB) + comprehensive `references/security-patterns-comprehensive.md` (~16KB, growable)
- **Skill.md:** Quick-reference with three phases (Pre-Install, Install Safety, Post-Install), attack patterns table, pointer to references
- **References file covers:** Pre-installation checks, installation safety, post-install audit, CI workflow checks, known attack patterns (lifecycle scripts, typosquatting, dependency confusion, cache poisoning, OIDC extraction, dead-man's switch, worm propagation, exotic dependency injection, forged commit identity, bot activity, README manipulation, Git submodule RCE CVE-2024-32002, repojacking, VS Code tasks.json abuse, secret leakage), AI-era specific risks (AI coding agent injection, MCP server vectors, LLM social engineering, prompt injection via PR/issue comments), well-known security tooling repos with star counts, invocation strategy with staged workflow and "Which Tool When" decision table, one-liner health checks, pre-install tool commands, safe cloning practices
- **Changelog:** v1.0.0 initial, v1.1.0 added deep research findings

### 5. Parallel Deep Research Task
- **Task ID:** `trun_128cf3d7716e46e9a9616abb17296956`
- **Processor:** pro-fast
- **Duration:** ~4 minutes
- **Findings:** Maintainer account takeovers (Axios April 2026, eslint-config-prettier July 2025, s1ngularity Nx August 2025, Shai-Hulud September 2025), GitHub Actions cache poisoning, Git submodule RCE (CVE-2024-32002), VS Code tasks.json abuse, repojacking, prompt injection via PR/issue comments ("Comment and Control"), MCP server exploitation, tooling (npq, gitleaks, semgrep, osv-scanner, trivy, Snyk CLI), statistics (39M secret leaks 2024, 28M in 2025, 64% of 2022 leaks still active 2026)

### 6. Security Toolkit Install Script
- **File:** `scripts/install-security-toolkit.sh`
- **Architecture-aware:** Detects aarch64 vs x86_64
- **Checksum verification:** gitleaks tarball verified against official GitHub checksums
- **Safety features:** Architecture auto-detect, checksum verification before `sudo`, idempotent, temp cleanup via `trap`, no blind `sudo` on downloads, npq self-audit
- **Tools:** gitleaks (GitHub release + verify), semgrep (`uv tool install`), osv-scanner (`go install` or binary + verify), trivy (signed APT repo), npq (npm global with pre-check)
- **Status:** Created, syntax-checked, executable. Not yet run.

### 7. System Update Discussion
- SSH login shows: 79 regular updates, 16 ESM security updates, restart required
- Recommended: `sudo apt update && sudo apt upgrade`
- ESM optional via `sudo pro attach` (free personal tier, up to 5 machines)
- Reboot: user controls timing

## Decisions Made
- [x] Device not affected by TanStack campaign
- [x] LinkedIn post finalized at 202 words
- [x] repo-security-audit skill created with split architecture
- [x] Security toolkit install script created
- [x] Parallel deep research completed and integrated
- [ ] Sandbox evaluation deferred

## Action Items
- [ ] Run `bash scripts/install-security-toolkit.sh`
- [ ] Publish LinkedIn post
- [ ] Evaluate systemd-nspawn dev sandbox in future session
- [ ] `sudo apt update && sudo apt upgrade`
- [ ] `sudo reboot`

## Code/Config References
- `SKILL.md` — lightweight quick-reference
- `references/security-patterns-comprehensive.md` — comprehensive patterns
- `scripts/install-security-toolkit.sh` — architecture-aware installer
- TanStack postmortem: https://tanstack.com/blog/npm-supply-chain-compromise-postmortem
- GitHub Advisory: https://github.com/TanStack/router/security/advisories/GHSA-g7cv-rxg3-hmpx
- Parallel research: `trun_128cf3d7716e46e9a9616abb17296956`
