# Concept Evolution: repo-security-audit

> **What this document is:** A chronological trace of how this repository's conceptual architecture evolved from its origin to its current state. It exists so any future contributor understands not just what the files contain, but why they are structured the way they are.

---

## A — The Origin (Trigger: May 11, 2026)

The TanStack npm supply chain compromise (CVE-2026-45321) exposed a critical gap: there was no lightweight, systematic framework for a non-coder to evaluate open-source repositories and npm packages before installing them.

**Core insight that shaped everything:** Most compromises can be spotted without downloading anything. Remote reconnaissance via `curl` and `npm info` catches 90% of threats. The remaining 10% requires deeper tools — but only if the surface check passes first.

**Target audience locked in from day one:** Non-coders who install tools and dependencies but do not maintain packages. All advice must be framed from that perspective. No CI/CD hardening advice that does not apply to them.

---

## B — The Initial Concept (v1.0.0)

### B.1 Split Architecture

The first architectural decision: separate lightweight quick-reference from growable comprehensive detail.

| File | Purpose | Constraint |
|------|---------|------------|
| `SKILL.md` | Quick-reference skill | Keep under 5KB. Append-only, never bloat. |
| `references/security-patterns-comprehensive.md` | Detailed patterns, commands, tooling | Growable. This is where new attack patterns live. |

**Rationale:** A 16KB monolithic file is intimidating for quick lookups. A 3KB quick-reference plus a separate reference file serves both use cases.

### B.2 Three-Stage Framework

The initial framework divided security checks into three stages based on commitment level:

| Stage | Commitment | When to Use |
|-------|-----------|-------------|
| **1. Remote Recon** | Zero — just `curl` and `npm info` | Always |
| **2. Surface Red Flags** | Zero — still HTTP calls only | If Stage 1 passes but you're cautious |
| **3. Deep Audit** | Clone to `/tmp` first, isolated | If you want certainty |

**Rationale:** Never skip Stage 1. Most threats are visible without a clone.

### B.3 Install Script Creation

`scripts/install-security-toolkit.sh` was created to install 5 security tools for Stage 3:
- **gitleaks** — Secret scanning in Git history
- **semgrep** — Static analysis for suspicious patterns
- **osv-scanner** — Known vulnerability lookup
- **trivy** — Comprehensive filesystem + config + secret scan
- **npq** — Pre-install npm package sanity check

**Safety principles embedded from the start:**
- Architecture auto-detect (aarch64 vs x86_64)
- SHA256 checksum verification before `sudo`
- Idempotent (skips already-installed tools)
- No blind `sudo` on downloaded content
- npq self-audited before install (the script checks its own target for install scripts)

**Critical principle:** The install commands for security tools must themselves be audited with the same staged framework the skill recommends for any other repo.

### B.4 Operational Guide

`AGENTS.md` was created as the operational guide for future contributors. It documents:
- Why the skill was split into lightweight + comprehensive
- What attack patterns were prioritized
- The staged framework
- How to extend the skill when new attack patterns emerge
- Content creation voice (non-coder, self-deprecating, bridge between technical and general audience)
- Confidence labels (mandatory: [CONFIRMED], [OBSERVED], [UNCERTAIN], [VERIFYING])

---

## C — Deep Research Integration (v1.1.0)

A parallel deep research task augmented the comprehensive reference with real incidents, statistics, and tooling data from 2024-2026.

### C.1 New Attack Patterns Added

- **CVE-2024-32002** — Git submodule RCE via `post-checkout` hook during `git clone --recursive`
- **Repojacking** — Attacker claims abandoned namespace after owner changes/deletes account
- **VS Code tasks.json abuse** — Malicious `.vscode/tasks.json` executes commands on project open
- **Secret leakage statistics** — 39M leaks in 2024, 28M in 2025, 64% of 2022 leaks still active in 2026
- **Additional ATO examples** — eslint-config-prettier (July 2025), s1ngularity Nx (August 2025)

### C.2 AI-Era Specific Risks

- **AI coding agent injection** — Malware drops files into `.claude/`, `.cursorrules`, `.vscode/` to hook into AI agent tool events
- **MCP server attack vectors** — Malicious MCP servers launched via `npx` have filesystem access, can read env vars, and exfiltrate data
- **LLM-powered social engineering** — Attackers use AI to generate convincing phishing to trick maintainers
- **Prompt injection via PR/issue comments** — Specially crafted GitHub comments trick AI agents into executing arbitrary commands

### C.3 Tooling References Added

The comprehensive reference added a "Well-Known Security Tooling Repos" table with star counts, install methods, and user-relevance flags. New tools added: gitleaks, semgrep, osv-scanner, trivy, TruffleHog.

### C.4 Safe Cloning Practices

Added explicit guidance:
- Never `git clone --recursive` on untrusted repos
- `git clone --no-recursive` → inspect submodules manually → `git submodule init` only if trusted

---

## D — Agent-Agnostic Refactor and Production Hardening (v1.2.0)

### D.1 The Problem: Framework Lock-In

`SKILL.md` used Hermes-specific syntax: YAML frontmatter, `skill_view()` calls, Hermes tags. This prevented adoption by agents that do not use the Hermes skill system.

**Solution:** Created `AGENT_ADOPTION.md` — a fully agent-agnostic markdown file with no framework-specific syntax. It contains the complete quick-reference, staged framework, attack patterns, decision tables, and safe practices. Any agent (Droid, Hermes, Claude Code, Cursor, etc.) can read and apply it directly.

### D.2 The Problem: Blurred Stage Boundaries

The original "Three Stages" framework (Remote Recon → Surface Red Flags → Deep Audit) grouped everything that needs a clone under Stage 3. But it did not clearly distinguish between:
- Checks that are **always available** (just need `curl`, `npm`, `jq`)
- Checks that are **conditional** (need the security toolkit installed first)

This led to agents potentially trying to run `gitleaks` or `semgrep` when they had not been installed yet.

**Solution:** Refactored from "Three Stages" to "Two Levels":

| Level | Availability | Tools | Needs Clone? |
|-------|-------------|-------|-------------|
| **1. Surface Check** | Always — just `curl`, `npm`, `jq` | GitHub API, npm info, Advisory DB, raw file curl | No |
| **2. Deep Dive** | Only after toolkit install | gitleaks, semgrep, osv-scanner, trivy | Yes |

**Rationale:** Level 1 is the baseline that works on any system immediately. Level 2 is the optional upgrade for when you need full code-level assurance. The prerequisite is explicit: `bash scripts/install-security-toolkit.sh`.

**Files updated:**
- `SKILL.md` — Rewrote "Three Phases" → "Two Levels", added prerequisite note
- `AGENT_ADOPTION.md` — Complete rewrite of strategy section with Level 1/2 split
- `references/security-patterns-comprehensive.md` — Refactored "Invocation Strategy" from Three Stages → Two Levels, updated decision table

### D.3 The Problem: Install Script Never Actually Ran

The install script was created, syntax-checked, and marked executable — but it was never actually executed. Three bugs were discovered on first run:

**Bug 1 — `local` outside functions:** bash rejected `local` declarations in top-level code blocks. Fixed by removing all `local` keywords from gitleaks, osv-scanner, npq, and summary loop sections.

**Bug 2 — Checksum URL redirect failure:** GitHub's `/releases/latest/download/filename` redirect works for binary assets but returns empty for text files (checksums). Fixed by using the tag-based path `/releases/download/v${VERSION}/filename`.

**Bug 3 — Checksum grep mismatch:** The `verify_github_checksum` function searched for the temp filename (`gitleaks.tar.gz`) in the checksums file, but the checksums file lists the original release filename (`gitleaks_8.30.1_linux_x64.tar.gz`). Fixed by adding a third parameter to pass the original filename for grep search.

**Result:** All 5 tools installed successfully to standard locations:
- gitleaks 8.30.1 → `/usr/local/bin/gitleaks`
- semgrep 1.163.0 → `~/.local/bin/semgrep`
- osv-scanner 2.3.8 → `~/go/bin/osv-scanner` (copied to `/usr/local/bin`)
- trivy 0.70.0 → `/usr/bin/trivy` (via APT)
- npq 3.19.2 → `~/.npm-global/bin/npq`

All locations are on PATH and available system-wide across all projects.

### D.4 The Problem: Toolkit Tools Themselves Not Audited

The skill recommended auditing install commands with the same staged framework. But the 5 toolkit tools themselves had not had their Stage 1/2 remote recon documented.

**Action:** Ran full remote recon on all 5 tools before installing:
- GitHub API health checks (stars, forks, last commit, license, open issues)
- Recent commit author verification (check for forged identities)
- CI workflow danger signal checks (`pull_request_target`, `id-token: write`)
- `.vscode/tasks.json` abuse checks
- GitHub Advisory Database CVE checks

**Results:** All 5 tools passed with [CONFIRMED] safe verdict. No danger signals found. No known CVEs specifically affecting these tools.

**Documentation:** The full safety audit is embedded in `AGENT_ADOPTION.md` under "Safety Audit: Five Security Toolkit Tools".

---

## Current State (v1.2.0)

### File Architecture

| File | What It Does | Who Edits It |
|------|-------------|------------|
| `SKILL.md` | Hermes quick-reference skill (v1.2.0) | Agents (keep lightweight) |
| `AGENT_ADOPTION.md` | Agent-agnostic adoption guide with full safety audit | Agents (when architecture changes) |
| `references/security-patterns-comprehensive.md` | Detailed attack patterns, commands, tooling (v1.2.0) | Agents (append-only) |
| `AGENTS.md` | Operational guide for future agents | Agents (when process changes) |
| `README.md` | User-facing overview | Agents (when scope changes) |
| `CONCEPT.md` | This file — conceptual evolution | Agents (when architecture evolves) |
| `scripts/install-security-toolkit.sh` | Installer for 5 security tools (v1.2.0) | Agents (when adding new tools) |

### Skill Architecture: Two Levels

**Level 1 — Surface Check (Always Available)**
- GitHub health signals via API
- npm registry metadata and install script detection
- GitHub Advisory Database CVE lookup
- Exotic dependency detection (raw `package.json` curl)
- VS Code tasks.json abuse check
- AI agent injection file detection (`.claude/`, `.cursorrules`)
- CI workflow danger signal checks
- Forged commit identity verification
- Post-install persistence checks (`grep`, `npm audit`)

**Level 2 — Deep Dive (Requires Security Toolkit)**
- `gitleaks detect --source .` — secret scan of full Git history
- `semgrep scan -q -d .` — suspicious code pattern analysis
- `osv-scanner scan -r .` — known vulnerability lookup
- `trivy fs --security-checks vuln,config,secret .` — comprehensive everything-at-once scan

### Key Decisions Preserved

1. **User perspective is non-coder.** No CI/CD hardening advice that does not apply to them.
2. **Split architecture.** Lightweight skill + growable references. Do not merge them.
3. **Level 1 before Level 2.** Surface Check saves you from 90% of threats without downloading anything.
4. **Install scripts are self-audited.** The security tools' own install commands were checked with the same framework.
5. **Sandbox is future work.** systemd-nspawn dev sandbox was discussed but deferred. Do not promise it without building it.

### Open Work

- Evaluate systemd-nspawn dev sandbox for isolated dev environments
- `sudo apt update && sudo apt upgrade` (79 regular updates, 16 ESM security updates pending)
- As new attack patterns emerge, append to `references/security-patterns-comprehensive.md` and update quick-reference tables in `SKILL.md` and `AGENT_ADOPTION.md`

---

## Changelog

- **v1.2.0** — Refactored: "Three Stages" → "Two Levels" (Surface Check vs Deep Dive). Created `AGENT_ADOPTION.md` for agent-agnostic adoption. Fixed install script bugs (local vars, checksum URLs, grep mismatch). Ran full safety audit of all 5 toolkit tools. All tools installed and verified.
- **v1.1.0** — Added: CVE-2024-32002, repojacking, VS Code tasks.json abuse, secret leakage stats, prompt injection via comments, AI-era risks (MCP vectors, LLM social engineering). Added tools: gitleaks, semgrep, osv-scanner, trivy, TruffleHog.
- **v1.0.0** — Initial: Lightweight `SKILL.md` + comprehensive `references/security-patterns-comprehensive.md`. Three-stage framework. Install script created. `AGENTS.md` operational guide.
