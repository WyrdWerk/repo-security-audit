# AGENTS.md — repo-security-audit

## What This Repository Is

This is a **Hermes skill** for repository and package security auditing. It was created after the TanStack npm supply chain compromise (May 11, 2026) to provide a systematic, staged approach to evaluating GitHub repositories and npm packages before installation.

**Key design principle:** The user is a non-coder who installs tools and dependencies but doesn't maintain packages. All advice is framed from that perspective.

**Architecture:**
- `SKILL.md` — Lightweight quick-reference (~3KB). Use this for fast lookups.
- `references/security-patterns-comprehensive.md` — Detailed patterns, commands, and tooling (~16KB, growable). Append new patterns here without touching the lightweight file.
- `scripts/install-security-toolkit.sh` — Architecture-aware installer for the 5 core security tools.

---

## If You're Picking This Up

### 1. Read the Context First

Start with `CONCEPT.md` in this repo. It traces the conceptual evolution of this repository from origin to current state. You'll understand:
- Why the skill was split into lightweight + comprehensive
- What attack patterns were prioritized
- What the user's voice sounds like (important if you're writing content from their perspective)
- What decisions were made and why

### 2. Read the Research

`RESEARCH.md` contains the parallel deep research output (~3,500 words) on npm supply chain threats 2024-2026. This is the raw intelligence that fed into the references file. It has:
- Real incident names and dates
- Tooling recommendations with star counts
- Statistics on secret leakage
- Gaps and recommendations for future work

### 3. Understand the Staged Framework

Every security check follows **two levels**:

| Stage | Commitment | When to Use |
|-------|-----------|-------------|
| **1. Surface Check** | Zero — just `curl`, `npm`, `jq` | Always, before any clone or install |
| **2. Deep Dive** | Requires security toolkit (`gitleaks`, `semgrep`, `osv-scanner`, `trivy`) | If you want certainty before putting it on your main system |

**Never skip Level 1.** Most compromises can be spotted without downloading anything.

### 4. Extending the Skill

When a new attack pattern emerges:
1. Add it to `references/security-patterns-comprehensive.md` under "Known Attack Patterns"
2. Include: How it works, real incident with date, defense, command if applicable
3. If it affects Level 1, add a row to the quick-reference table in `SKILL.md`
4. Update the Changelog in both files
5. If it introduces a new tool, add it to "Well-Known Security Tooling Repos" with star count and command

**Do NOT** bloat `SKILL.md`. Keep it under 5KB. The comprehensive file is where detail lives.

### 5. The Install Script

`scripts/install-security-toolkit.sh` installs 5 tools:
- **gitleaks** (18k+ stars) — Secret scanning in Git history
- **semgrep** (15k+ stars) — Static analysis for suspicious patterns
- **osv-scanner** (6k+ stars) — Known vulnerability lookup
- **trivy** (25k+ stars) — Comprehensive filesystem + config + secret scan
- **npq** (~500 stars) — Pre-install npm package sanity check

**Safety features:**
- Architecture auto-detect (aarch64 vs x86_64)
- SHA256 checksum verification for GitHub release binaries
- Idempotent (skips already-installed tools)
- No blind `sudo` on downloaded content
- npq is self-audited before install

**Before modifying the script:** Audit any new install commands with the same staged framework. See the install commands audit in `CONCEPT.md`.

### 6. Content Creation from This Skill

If you're writing LinkedIn posts, blog articles, or briefs from this material:
- **Voice:** Non-coder who had to ask AI to explain things. Self-deprecating, curious, not an authority.
- **Angle:** Bridge between technical and general audience. "Here's what I learned after asking a bunch of questions."
- **Process:** Draft → anbeeld-writing structural pass → humanizer-pass voice injection
- **Length:** 200-225 words for LinkedIn feed posts

### 7. Confidence Labels Are Mandatory

Every factual claim in outputs must carry a label:
- **[CONFIRMED]** — You ran the tool and saw the output
- **[OBSERVED]** — You see it in the file but haven't tested
- **[UNCERTAIN]** — Pattern-matching, could be legitimate
- **[VERIFYING]** — You intend to check

Never assert without evidence.

### 8. Key Decisions to Preserve

1. **User perspective is non-coder.** No CI/CD hardening advice that doesn't apply to them.
2. **Split architecture.** Lightweight skill + growable references. Don't merge them.
3. **Level 1 before Level 2.** Surface Check saves you from 90% of threats without downloading anything.
4. **Install scripts are self-audited.** The security tools' own install commands were checked with the same framework.
5. **Sandbox is future work.** systemd-nspawn dev sandbox was discussed but deferred. Don't promise it without building it.

---

## Next Work (If Continuing)

1. **Run the install script:** `bash scripts/install-security-toolkit.sh` on the user's machine
2. **Test the tools:** Pick a safe repo, run Stage 3 commands, verify they work
3. **Sandbox evaluation:** Explore systemd-nspawn for isolated dev environments
4. **New patterns:** As incidents happen, append to `references/security-patterns-comprehensive.md`
5. **Content:** Publish the LinkedIn post when user is ready

---

## Files and Their Purpose

| File | What It Does | Who Edits It |
|------|-------------|-------------|
| `SKILL.md` | Quick-reference skill for Hermes | Agents (keep lightweight) |
| `references/security-patterns-comprehensive.md` | Detailed attack patterns, commands, tooling | Agents (append-only) |
| `AGENTS.md` | This file — operational guide for future agents | Agents (update when process changes) |
| `README.md` | User-facing overview | Agents (update when scope changes) |
| `CONCEPT.md` | Conceptual evolution of the repository architecture | Read-only (historical record) |
| `RESEARCH.md` | Embedded parallel research artifact | Read-only (historical record) |
| `scripts/install-security-toolkit.sh` | Installer for 5 security tools | Agents (when adding new tools) |

---

## Contact / Context

- Created: May 15, 2026 by Hermes Agent (session: `20260515-101637-hermes`)
- User: yash (WyrdWerk)
- Trigger: TanStack npm supply chain compromise (CVE-2026-45321)
- Full conversation: `WyrdWerk/agentic-memory-hub/conversations/2026/05/15/20260515-101637-hermes.md`
