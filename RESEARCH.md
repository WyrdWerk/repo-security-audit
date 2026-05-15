# Embedded Research Artifact: NPM Supply Chain Threats 2024-2026

**Source:** Parallel AI Deep Research Task  
**Task ID:** `trun_128cf3d7716e46e9a9616abb17296956`  
**Platform URL:** https://platform.parallel.ai/view/task-run/trun_128cf3d7716e46e9a9616abb17296956  
**Processor:** pro-fast  
**Date:** May 15, 2026  
**Type:** research-brief  
**Word Count:** ~3,500  
**Status:** final

---

## Executive Summary

The software supply chain threat landscape has evolved significantly between 2024 and 2026, shifting from simple typosquatting to sophisticated maintainer account takeovers, AI agent hijacking, and persistent cache poisoning. For users consuming open-source packages, the risk is no longer just about what code is in the repository, but how the repository's infrastructure and associated AI tools can be weaponized.

Key findings indicate that npm account takeovers hit an all-time high in 2025. High-profile packages like Axios were compromised via social engineering, delivering cross-platform Remote Access Trojans (RATs) to downstream users. Furthermore, the rise of AI coding assistants has introduced a new attack surface: "Comment and Control" prompt injections that trick AI agents into executing malicious commands or exfiltrating secrets.

GitHub's own security report counted 39 million secret leaks in 2024, and an academic study analyzing over 80 million files found that 28 million credentials leaked on GitHub in 2025. Alarmingly, 64% of secrets leaked in 2022 were still active in 2026.

## Recurring Attack Patterns

### Maintainer Account Takeovers

Account takeovers (ATOs) are some of the most harmful malware campaigns, often starting by compromising a maintainer account through social engineering. In April 2026, the Axios npm package was compromised to drop cross-platform malware after the maintainer was social-engineered into installing a RAT on their machine. This was not an isolated incident; attackers used fake Teams error fixes to hijack maintainer accounts across the Node.js ecosystem. Other notable ATOs in 2025 included `eslint-config-prettier` (July 2025), `s1ngularity Nx` (August 2025), and the massive `Shai-Hulud` campaign (September 2025) which weaponized the open-source secret scanner TruffleHog to expose credentials from 26,300 repos.

### GitHub Actions Cache Poisoning

Shared build caches have become a silent backdoor. In the TanStack npm supply-chain compromise, attackers exploited the `pull_request_target` trigger, which runs in the context of the base repository. A malicious PR running in the base repo's cache scope can poison entries that production workflows on the main branch will later restore. This GitHub Actions cache poisoning across trust boundaries allows attackers to turn the shared build cache into a supply chain weapon.

### Submodule & Symlink RCE (CVE-2024-32002)

A critical vulnerability in Git enables remote code execution attacks by manipulating Git repositories using submodules. The bug allows files to be written outside the submodule's work tree and into the `.git/` directory, enabling the execution of a malicious hook while a repository cloning operation is still running. When a user clones a malicious repository using the `--recursive` option, a malicious script from a `post-checkout` hook can be triggered, compromising the user's device.

### VS Code /.vscode Abuse

Threat actors are abusing the `.vscode/tasks.json` file to facilitate malicious command execution. Over a 72-hour period, 21 contributors had their repositories compromised with potentially malicious `.vscode/tasks.json` files that silently executed commands. Because the presence of a `tasks.json` file is innocuous, users may not suspect anything, allowing the file to execute a multi-stage infostealer deployment.

### Repojacking & Namespace Abuse

Repojacking occurs when a developer changes or deletes their account on GitHub and doesn't perform a namespace retirement, allowing attackers to claim the abandoned namespace. An analysis revealed that 336K Prometheus instances were exposed to DoS and repojacking due to this vulnerability.

## AI-Era Specific Vectors

### Prompt-Injection via PR/Issue Comments

AI agents that ingest untrusted GitHub data are vulnerable to prompt injection. A researcher disclosed the "Comment and Control" attack method, which works against Anthropic's Claude Code Security Review, Google's Gemini CLI Action, and GitHub Copilot Agent. Attackers can use specially crafted GitHub comments, including PR titles, issue bodies, and hidden HTML comments, to trick the AI agent into executing arbitrary commands and extracting credentials.

### MCP Server Exploitation Surface

Model Context Protocol (MCP) servers let AI coding assistants run tools directly. For example, the Semgrep MCP Server integrates with Cursor, VS Code, Windsurf, and Claude Desktop. However, if these agents process untrusted input with access to tools and secrets in the same runtime, they can be bypassed and weaponized.

## Red-Flag Checklist for Non-Coders

Users auditing repositories should look for specific visual cues that indicate potential compromise:

- **Exotic Dependency URLs:** Dependencies pointing to `git+ssh://` or arbitrary tarball URLs instead of standard npm registry versions.
- **Suspicious File Patterns:** Unexpected `.vscode/tasks.json` files, hidden `.claude/` or `.cursorrules` configurations, or unexpected `.git` symlinks.
- **Bot-Account Masquerading:** Commits from generic bot names without verified status, or workflows executing commands using unsanitized input from PR titles.

## Security-Tooling Landscape

| Tool / Repo | Primary Focus | Quick-Start Command |
|-------------|---------------|---------------------|
| **gitleaks** | Secret scanning | `gitleaks detect --source .` |
| **semgrep** | Code-pattern static analysis | `semgrep scan -q -d .` |
| **npq** | Pre-install npm-package sanity check | `npq audit <package>` |
| **osv-scanner** | Vulnerability lookup via OSV DB | `osv-scanner scan -r .` |
| **trivy** | Config & secret scanning for repos | `trivy fs --security-checks vuln,config .` |
| **Snyk CLI** | Full-stack SCA scanning | `snyk test` |

## Repo-Security Audit Playbook (User-Facing)

### Pre-install Quick Check

Use `npq` to safely install npm packages by auditing them in the pre-install stage:

```bash
npm i -g npq
npq audit <package-name>
```

### CI SCA Integration

Integrate vulnerability scanners into your CI pipeline to catch issues early:

```yaml
name: Security Scan
on: [push, pull_request]
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run OSV-Scanner
        run: |
          curl -L https://github.com/google/osv-scanner/releases/latest/download/osv-scanner_linux_amd64 -o osv-scanner
          chmod +x osv-scanner
          ./osv-scanner -r .
```

### Cache-Poison Guardrails

To prevent GitHub Actions cache poisoning, ensure that workflows triggered by `pull_request_target` do not write to shared caches. Set permissions to read-only where possible:

```yaml
permissions:
  contents: read
```

### Safe Cloning Practices

To mitigate Git submodule vulnerabilities like CVE-2024-32002, avoid recursive cloning of untrusted repositories:

```bash
git clone --no-recursive <repository-url>
```

## Gaps, Recommendations & Future Outlook

Despite advancements in security tooling, significant gaps remain. The fact that 64% of leaked secrets remain active after a year highlights a failure in remediation processes. Furthermore, the introduction of AI coding agents has expanded the attack surface, allowing untrusted GitHub data to execute commands via prompt injection.

Users must prioritize immediate actions: rotate leaked secrets immediately, enforce 2FA on all accounts, and sandbox AI agents to prevent them from accessing production secrets. Long-term strategies should include pushing for mandatory provenance, adopting GitHub's Trusted Publishing (OIDC) to reduce reliance on long-lived tokens, and enforcing strict namespace retirement policies to prevent repojacking.

## References

1. npm Account Takeovers are a Growing Malware Trend — endorlabs.com
2. Compromised axios npm package delivers cross-platform RAT — Datadog Security Labs
3. Axios Compromised on npm, What the Malicious Releases Actually Did — penligent.ai
4. Claude Code, Gemini CLI, GitHub Copilot Agents Vulnerable to Prompt Injection via Comments — SecurityWeek
5. Why 28 million credentials leaked on GitHub in 2025, and what to do — Snyk
6. The Social Engineering Playbook Attackers Use to Target Open Source — opensourcemalware.com
7. Axios npm hack used fake Teams error fix to hijack maintainer account — BleepingComputer
8. Postmortem: TanStack npm supply-chain compromise — tanstack.com
9. The Cache That Bites Back: GitHub Actions Cache Poisoning Attacks — hivesecurity.gitlab.io
10. Analyzing and Remediating Git Vulnerability CVE-2024-32002 — opswat.com
11. Malicious VS Code tasks.json abuse enables multi-stage infostealer — threatlocker.com
12. Small Open-Source Maintainers Targeted by VS Code Tasks Malware — opensourcemalware.com
13. 336K Prometheus Instances Exposed to DoS, 'Repojacking' — darkreading.com
14. Semgrep GitHub Repository — github.com/returntocorp/semgrep
15. npq: safely install npm packages by auditing them — github.com/lirantal/npq
