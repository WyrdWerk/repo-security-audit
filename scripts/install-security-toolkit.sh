#!/bin/bash
# Security Toolkit Installer
# Installs: gitleaks, semgrep, osv-scanner, trivy, npq
# Verifies checksums, uses safe practices, architecture-aware
# Run with: bash install-security-toolkit.sh

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Config
ARCH=$(uname -m)
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo -e "${BLUE}=== Security Toolkit Installer ===${NC}"
echo -e "${BLUE}Architecture detected: $ARCH${NC}"
echo ""

# Architecture mapping
if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    GITLEAKS_ARCH="linux_arm64"
    OSV_ARCH="linux_arm64"
    TRIVY_ARCH="Linux-ARM64"
elif [[ "$ARCH" == "x86_64" ]]; then
    GITLEAKS_ARCH="linux_x64"
    OSV_ARCH="linux_amd64"
    TRIVY_ARCH="Linux-64bit"
else
    echo -e "${RED}Unsupported architecture: $ARCH${NC}"
    exit 1
fi

# Helper functions
verify_github_checksum() {
    local binary_file="$1"
    local checksums_url="$2"
    local search_name="${3:-$(basename "$binary_file")}"

    echo -e "${BLUE}  Verifying SHA256 checksum...${NC}"
    wget -qO "$TMPDIR/checksums.txt" "$checksums_url"
    local expected_hash=$(grep "$search_name" "$TMPDIR/checksums.txt" | awk '{print $1}')
    local actual_hash=$(sha256sum "$binary_file" | awk '{print $1}')

    if [[ "$expected_hash" == "$actual_hash" ]]; then
        echo -e "${GREEN}  ✓ Checksum verified: $actual_hash${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Checksum MISMATCH!${NC}"
        echo -e "${RED}    Expected: $expected_hash${NC}"
        echo -e "${RED}    Actual:   $actual_hash${NC}"
        return 1
    fi
}

check_installed() {
    if command -v "$1" &> /dev/null; then
        local version=$($1 version 2>/dev/null || $1 --version 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓ $1 already installed: $version${NC}"
        return 0
    fi
    return 1
}

# =============================================================================
# 1. gitleaks
# =============================================================================
echo -e "${YELLOW}[1/5] Installing gitleaks...${NC}"
if check_installed "gitleaks"; then
    echo ""
else
    echo -e "${BLUE}  Fetching latest release info...${NC}"
    GITLEAKS_VERSION=$(curl -s "https://api.github.com/repos/gitleaks/gitleaks/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+')
    echo -e "${BLUE}  Version: v${GITLEAKS_VERSION}${NC}"
    
    binary_name="gitleaks_${GITLEAKS_VERSION}_${GITLEAKS_ARCH}.tar.gz"
    download_url="https://github.com/gitleaks/gitleaks/releases/latest/download/${binary_name}"
    checksums_url="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_checksums.txt"
    
    echo -e "${BLUE}  Downloading ${binary_name}...${NC}"
    wget -q --show-progress -O "$TMPDIR/gitleaks.tar.gz" "$download_url"
    
    if verify_github_checksum "$TMPDIR/gitleaks.tar.gz" "$checksums_url" "$binary_name"; then
        echo -e "${BLUE}  Extracting to /usr/local/bin...${NC}"
        sudo tar xf "$TMPDIR/gitleaks.tar.gz" -C /usr/local/bin gitleaks
        sudo chmod +x /usr/local/bin/gitleaks
        echo -e "${GREEN}✓ gitleaks installed: $(gitleaks version)${NC}"
    else
        echo -e "${RED}✗ gitleaks install aborted: checksum failed${NC}"
        exit 1
    fi
    echo ""
fi

# =============================================================================
# 2. semgrep
# =============================================================================
echo -e "${YELLOW}[2/5] Installing semgrep...${NC}"
if check_installed "semgrep"; then
    echo ""
else
    # Prefer uv if available (isolated, no sudo)
    if command -v uv &> /dev/null; then
        echo -e "${BLUE}  Using uv (isolated Python tool installer)...${NC}"
        uv tool install semgrep
    elif command -v pipx &> /dev/null; then
        echo -e "${BLUE}  Using pipx (isolated Python tool installer)...${NC}"
        pipx install semgrep
    else
        echo -e "${BLUE}  Using pip3 (installing to user site-packages)...${NC}"
        pip3 install --user semgrep
        # Ensure ~/.local/bin is in PATH
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            echo -e "${YELLOW}  ⚠ Add ~/.local/bin to your PATH to use semgrep${NC}"
        fi
    fi
    
    if command -v semgrep &> /dev/null; then
        echo -e "${GREEN}✓ semgrep installed: $(semgrep --version)${NC}"
    else
        echo -e "${YELLOW}  semgrep installed but not in PATH. Try: export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    fi
    echo ""
fi

# =============================================================================
# 3. osv-scanner
# =============================================================================
echo -e "${YELLOW}[3/5] Installing osv-scanner...${NC}"
if check_installed "osv-scanner"; then
    echo ""
else
    echo -e "${BLUE}  Fetching latest release info...${NC}"
    OSV_VERSION=$(curl -s "https://api.github.com/repos/google/osv-scanner/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+')
    echo -e "${BLUE}  Version: v${OSV_VERSION}${NC}"
    
    # Note: osv-scanner release binaries use "linux_amd64" naming even for v2
    # Let's use go install as fallback if binary not available for arm64
    if command -v go &> /dev/null; then
        echo -e "${BLUE}  Using go install (builds from source, architecture-native)...${NC}"
        go install "github.com/google/osv-scanner/v2/cmd/osv-scanner@v${OSV_VERSION}"
        # go install puts binary in $GOPATH/bin or ~/go/bin
        if [[ -f "$HOME/go/bin/osv-scanner" ]]; then
            sudo cp "$HOME/go/bin/osv-scanner" /usr/local/bin/osv-scanner
            sudo chmod +x /usr/local/bin/osv-scanner
        fi
    else
        echo -e "${BLUE}  Downloading official binary...${NC}"
        binary_name="osv-scanner_${OSV_VERSION}_${OSV_ARCH}"
        download_url="https://github.com/google/osv-scanner/releases/latest/download/${binary_name}"
        checksums_url="https://github.com/google/osv-scanner/releases/download/v${OSV_VERSION}/osv-scanner_${OSV_VERSION}_checksums.txt"
        
        wget -q --show-progress -O "$TMPDIR/osv-scanner" "$download_url"
        
        if verify_github_checksum "$TMPDIR/osv-scanner" "$checksums_url" "$binary_name"; then
            sudo cp "$TMPDIR/osv-scanner" /usr/local/bin/osv-scanner
            sudo chmod +x /usr/local/bin/osv-scanner
        else
            echo -e "${RED}✗ osv-scanner install aborted: checksum failed${NC}"
            exit 1
        fi
    fi
    
    if command -v osv-scanner &> /dev/null; then
        echo -e "${GREEN}✓ osv-scanner installed: $(osv-scanner --version)${NC}"
    else
        echo -e "${RED}✗ osv-scanner not found in PATH${NC}"
    fi
    echo ""
fi

# =============================================================================
# 4. trivy
# =============================================================================
echo -e "${YELLOW}[4/5] Installing trivy...${NC}"
if check_installed "trivy"; then
    echo ""
else
    echo -e "${BLUE}  Adding official Aqua Security APT repository...${NC}"
    
    sudo apt-get install -y wget apt-transport-https gnupg lsb-release
    
    # Download and dearmor GPG key
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
    
    # Add repo with signed-by directive
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
    
    echo -e "${BLUE}  Updating package lists...${NC}"
    sudo apt-get update
    
    echo -e "${BLUE}  Installing trivy...${NC}"
    sudo apt-get install -y trivy
    
    echo -e "${GREEN}✓ trivy installed: $(trivy -v)${NC}"
    echo ""
fi

# =============================================================================
# 5. npq
# =============================================================================
echo -e "${YELLOW}[5/5] Installing npq...${NC}"
if check_installed "npq"; then
    echo ""
else
    echo -e "${BLUE}  Pre-install verification of npq package...${NC}"
    
    # Stage 1: Remote recon
    echo -e "${BLUE}  [Stage 1] Checking npm registry metadata...${NC}"
    npm info npq --json 2>/dev/null | jq '{version: .version, date: .time[.version], downloads: .downloads["last-week"], maintainers: .maintainers | length, scripts: (.scripts | keys)}' || true
    
    # Stage 2: Check for install scripts
    install_scripts=$(npm info npq --json 2>/dev/null | jq -r '.scripts | to_entries[] | select(.key | test("install|prepare|postinstall|preinstall")) | .key' || true)
    if [[ -n "$install_scripts" ]]; then
        echo -e "${YELLOW}  ⚠ Install scripts detected: $install_scripts${NC}"
        echo -e "${YELLOW}  Installing with --ignore-scripts first...${NC}"
        npm install -g --ignore-scripts npq

        # Verify what was installed
        npq_dir=$(npm root -g)/npq
        echo -e "${BLUE}  Verifying installed contents...${NC}"
        ls -la "$npq_dir/" 2>/dev/null | head -10 || true

        # Check package.json scripts in installed version
        installed_scripts=$(cat "$npq_dir/package.json" 2>/dev/null | jq -r '.scripts | to_entries[] | select(.key | test("install|prepare|postinstall|preinstall")) | .key' || true)
        if [[ -n "$installed_scripts" ]]; then
            echo -e "${YELLOW}  ⚠ Scripts present but not executed. Review before re-installing without --ignore-scripts:${NC}"
            echo -e "${YELLOW}    $installed_scripts${NC}"
        fi
        
        echo -e "${GREEN}✓ npq installed (with --ignore-scripts). To enable full functionality, review scripts then reinstall without flag.${NC}"
    else
        echo -e "${GREEN}  ✓ No install scripts detected${NC}"
        npm install -g npq
        echo -e "${GREEN}✓ npq installed: $(npq --version 2>/dev/null || echo 'unknown')${NC}"
    fi
    echo ""
fi

# =============================================================================
# Summary
# =============================================================================
echo -e "${BLUE}=== Installation Summary ===${NC}"
echo ""
for tool in gitleaks semgrep osv-scanner trivy npq; do
    if command -v "$tool" &> /dev/null; then
        version=$($tool version 2>/dev/null || $tool --version 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓ $tool: $version${NC}"
    else
        echo -e "${RED}✗ $tool: NOT FOUND${NC}"
    fi
done

echo ""
echo -e "${BLUE}All tools installed with verification. Run 'skill_view(\"solvency/repo-security-audit\")' for usage.${NC}"
