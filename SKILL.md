---
name: repo-security-audit
description: Quick security checklist for evaluating GitHub repos and npm packages before/after installation. For non-coders and users. Heavy details live in references/.
version: "1.1.0"
metadata:
  hermes:
    tags: [solvency, security, npm, github, supply-chain]
    category: solvency
---

# Repository Security Audit

Quick-check skill for users evaluating open-source repositories and npm packages. If you need deep detail on any pattern, load the comprehensive reference.

## When to Invoke

- Before cloning or installing anything unfamiliar
- After a major supply chain incident (check if you were affected)
- Weekly system health check for persistence files
- Before running `npm install` on a new project

## Target Audience

Non-coders who install tools and dependencies but don't maintain packages.

---

## Quick Reference: Three Phases

### Phase 1: Before You Install

```bash
# 1. Check the package on npm registry
npm info PACKAGE_NAME --json | jq '{version: .version, date: .time[.version], downloads: .downloads["last-week"], scripts: (.scripts | keys)}'

# 2. Look for install scripts (red flag if present)
npm info PACKAGE_NAME --json | jq '.scripts | to_entries[] | select(.key | test("install|prepare|postinstall|preinstall")) | .key'

# 3. Check GitHub repo health (no clone needed)
curl -s https://api.github.com/repos/OWNER/REPO | jq '{stars: .stargazers_count, forks: .forks_count, updated: .updated_at, open_issues: .open_issues_count}'
```

**If any of these look suspicious:** low downloads, recent publish with no history, install scripts present, stale repo — pause and investigate.

### Phase 2: Safe Installation

```bash
# Block ALL hidden code from running during install
npm install --ignore-scripts --allow-git=none

# Or try once without persisting
npx PACKAGE_NAME@VERSION
```

### Phase 3: After You Install

```bash
# Check for persistence files (run this after ANY unfamiliar install)
ls ~/.local/bin/gh-token-monitor.sh ~/.config/systemd/user/gh-token-monitor.service ~/Library/LaunchAgents/com.user.gh-token-monitor.plist 2>/dev/null
ls -d .claude/ .vscode/ 2>/dev/null
find . -name "router_init.js" -o -name "tanstack_runner.js" -o -name "setup.mjs" 2>/dev/null

# Check for suspicious network/file/exec patterns in the package
grep -rE "fetch\(|https?://|child_process|spawn|exec\(|process\.env|eval\(" node_modules/PACKAGE_NAME/ 2>/dev/null | head -10

# Run npm audit for known vulnerabilities
npm audit
```

---

## Key Attack Patterns (Summary)

| Pattern | What Happens | Your Defense |
|---------|-------------|-------------|
| **Lifecycle scripts** | `postinstall` runs hidden code during `npm install` | `--ignore-scripts` |
| **Typosquatting** | `axois` instead of `axios` | Double-check exact name |
| **Exotic deps** | Package uses `git+https` or tarball URLs | `--allow-git=none` |
| **Dead-man's switch** | Malware wipes your home if you revoke stolen token | Kill persistence files FIRST, then rotate tokens |
| **Worm propagation** | Malware republishes your packages with same injection | Audit your own npm packages for unexpected versions |
| **AI agent injection** | Malware drops files into `.claude/` or `.vscode/` | Check these directories after installs |
| **MCP server vector** | `npx` resolves latest version each time — compromised between runs | Pin exact versions for MCP tools |

---

## For Deep Detail

Load the comprehensive reference for:
- Full attack pattern breakdowns with real incidents
- All commands with explanations
- AI-era specific risks (Claude Code injection, MCP vectors, LLM social engineering)
- Well-known security tooling repos and their star counts
- One-liner combined health checks

```
skill_view("solvency/repo-security-audit", "references/security-patterns-comprehensive.md")
```

---

## Confidence Labels

When reporting findings:
- **[CONFIRMED]** — You ran the command and saw the output
- **[OBSERVED]** — You see it in the file but haven't tested functionality
- **[UNCERTAIN]** — Pattern matches known attack but could be legitimate
- **[VERIFYING]** — You intend to check but haven't yet

---

## Related Skills

- `solvency/boot-solvency` — Session start checklist
- `solvency/fact-discipline` — Claim verification before publishing
- `solvency/retrieval-hygiene` — Stale context audit

---

## Changelog

- v1.1.0 — Refactored: SKILL.md is now lightweight quick-reference; all detailed patterns moved to `references/security-patterns-comprehensive.md` (comprehensive, ~12KB, growable).
- v1.0.0 — Initial monolithic skill covering TanStack incident patterns.
