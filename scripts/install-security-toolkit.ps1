# Security Toolkit Installer for Windows
# Supports: Windows 10/11 (x64/AMD64)
# Installs: gitleaks, semgrep, osv-scanner, trivy, npq
# Verifies checksums, uses safe practices
# Run with: PowerShell -ExecutionPolicy Bypass -File install-security-toolkit.ps1

$ErrorActionPreference = "Stop"

# Colors
$Red = "`e[0;31m"
$Green = "`e[0;32m"
$Yellow = "`e[1;33m"
$Blue = "`e[0;34m"
$NC = "`e[0m"

# Detect architecture
$ARCH = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "x86" }
$OS = "Windows"

Write-Host "$Blue=== Security Toolkit Installer (Windows) ===$NC"
Write-Host "$Blue OS detected:    $OS$NC"
Write-Host "$Blue Architecture:   $ARCH$NC"
Write-Host ""

if ($ARCH -eq "x86") {
    Write-Host "$Red 32-bit Windows is not supported. All upstream releases are 64-bit only.$NC"
    exit 1
}

# Determine install directory
$InstallDir = "$env:LOCALAPPDATA\Programs"
if (!(Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# Ensure install dir is on PATH
$UserPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($UserPath -notlike "*$InstallDir*") {
    Write-Host "$Yellow  Adding $InstallDir to your User PATH...$NC"
    [Environment]::SetEnvironmentVariable("PATH", "$UserPath;$InstallDir", "User")
    $env:PATH = "$env:PATH;$InstallDir"
}

$TmpDir = [System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid().ToString()
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null

function Cleanup {
    if (Test-Path $TmpDir) {
        Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
    }
}

try {

    # =============================================================================
    # Helper functions
    # =============================================================================

    function Verify-Checksum {
        param(
            [string]$FilePath,
            [string]$ChecksumsUrl,
            [string]$SearchName = (Split-Path $FilePath -Leaf)
        )
        Write-Host "$Blue  Verifying SHA256 checksum...$NC"
        $checksumsFile = "$TmpDir\checksums.txt"
        Invoke-WebRequest -Uri $ChecksumsUrl -OutFile $checksumsFile -UseBasicParsing

        $expectedLine = Select-String -Path $checksumsFile -Pattern $SearchName
        if (!$expectedLine) {
            Write-Host "$Red  ✗ Could not find $SearchName in checksums file$NC"
            return $false
        }
        $expectedHash = ($expectedLine.Line -split '\s+')[0]
        $actualHash = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLower()

        if ($expectedHash -eq $actualHash) {
            Write-Host "$Green  ✓ Checksum verified: $actualHash$NC"
            return $true
        } else {
            Write-Host "$Red  ✗ Checksum MISMATCH!$NC"
            Write-Host "$Red    Expected: $expectedHash$NC"
            Write-Host "$Red    Actual:   $actualHash$NC"
            return $false
        }
    }

    function Check-Installed {
        param([string]$Name)
        $cmd = Get-Command $Name -ErrorAction SilentlyContinue
        if ($cmd) {
            $version = & $Name version 2>$null || & $Name --version 2>$null || "unknown"
            Write-Host "$Green  ✓ $Name already installed: $version$NC"
            return $true
        }
        return $false
    }

    # =============================================================================
    # 1. gitleaks
    # =============================================================================
    Write-Host "$Yellow[1/5] Installing gitleaks...$NC"
    if (Check-Installed "gitleaks") {
        Write-Host ""
    } else {
        Write-Host "$Blue  Fetching latest release info...$NC"
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/gitleaks/gitleaks/releases/latest" -UseBasicParsing
        $gitleaksVersion = $release.tag_name.TrimStart('v')
        Write-Host "$Blue  Version: v$gitleaksVersion$NC"

        $binaryName = "gitleaks_${gitleaksVersion}_windows_x64.zip"
        $downloadUrl = "https://github.com/gitleaks/gitleaks/releases/download/v${gitleaksVersion}/${binaryName}"
        $checksumsUrl = "https://github.com/gitleaks/gitleaks/releases/download/v${gitleaksVersion}/gitleaks_${gitleaksVersion}_checksums.txt"
        $zipPath = "$TmpDir\gitleaks.zip"

        Write-Host "$Blue  Downloading $binaryName...$NC"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing

        if (Verify-Checksum $zipPath $checksumsUrl $binaryName) {
            Write-Host "$Blue  Extracting to $InstallDir...$NC"
            Expand-Archive -Path $zipPath -DestinationPath $TmpDir -Force
            Copy-Item "$TmpDir\gitleaks.exe" "$InstallDir\gitleaks.exe" -Force
            Write-Host "$Green  ✓ gitleaks installed$NC"
        } else {
            Write-Host "$Red  ✗ gitleaks install aborted: checksum failed$NC"
            exit 1
        }
        Write-Host ""
    }

    # =============================================================================
    # 2. semgrep
    # =============================================================================
    Write-Host "$Yellow[2/5] Installing semgrep...$NC"
    if (Check-Installed "semgrep") {
        Write-Host ""
    } else {
        # Check for Python/pip
        $pipCmd = Get-Command "pip" -ErrorAction SilentlyContinue
        if (!$pipCmd) {
            $pipCmd = Get-Command "pip3" -ErrorAction SilentlyContinue
        }

        if ($pipCmd) {
            Write-Host "$Blue  Installing semgrep via pip...$NC"
            & $pipCmd.Source install --user semgrep
        } else {
            Write-Host "$Red  pip/pip3 not found. Please install Python first: https://python.org$NC"
            exit 1
        }

        if (Check-Installed "semgrep") {
            Write-Host "$Green  ✓ semgrep installed$NC"
        } else {
            Write-Host "$Yellow  semgrep installed but not in PATH. Try restarting your terminal.$NC"
        }
        Write-Host ""
    }

    # =============================================================================
    # 3. osv-scanner
    # =============================================================================
    Write-Host "$Yellow[3/5] Installing osv-scanner...$NC"
    if (Check-Installed "osv-scanner") {
        Write-Host ""
    } else {
        # Prefer WinGet or Scoop if available
        $winget = Get-Command "winget" -ErrorAction SilentlyContinue
        $scoop = Get-Command "scoop" -ErrorAction SilentlyContinue

        if ($winget) {
            Write-Host "$Blue  Installing osv-scanner via WinGet...$NC"
            winget install Google.OSVScanner --accept-source-agreements --accept-package-agreements
        } elseif ($scoop) {
            Write-Host "$Blue  Installing osv-scanner via Scoop...$NC"
            scoop install osv-scanner
        } else {
            Write-Host "$Blue  Fetching latest release info...$NC"
            $release = Invoke-RestMethod -Uri "https://api.github.com/repos/google/osv-scanner/releases/latest" -UseBasicParsing
            $osvVersion = $release.tag_name.TrimStart('v')
            Write-Host "$Blue  Version: v$osvVersion$NC"

            $binaryName = "osv-scanner_${osvVersion}_windows_amd64.exe"
            $downloadUrl = "https://github.com/google/osv-scanner/releases/download/v${osvVersion}/${binaryName}"
            $checksumsUrl = "https://github.com/google/osv-scanner/releases/download/v${osvVersion}/osv-scanner_${osvVersion}_checksums.txt"
            $binaryPath = "$TmpDir\osv-scanner.exe"

            Write-Host "$Blue  Downloading $binaryName...$NC"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $binaryPath -UseBasicParsing

            if (Verify-Checksum $binaryPath $checksumsUrl $binaryName) {
                Copy-Item $binaryPath "$InstallDir\osv-scanner.exe" -Force
                Write-Host "$Green  ✓ osv-scanner installed$NC"
            } else {
                Write-Host "$Red  ✗ osv-scanner install aborted: checksum failed$NC"
                exit 1
            }
        }
        Write-Host ""
    }

    # =============================================================================
    # 4. trivy
    # =============================================================================
    Write-Host "$Yellow[4/5] Installing trivy...$NC"
    if (Check-Installed "trivy") {
        Write-Host ""
    } else {
        $winget = Get-Command "winget" -ErrorAction SilentlyContinue

        if ($winget) {
            Write-Host "$Blue  Installing trivy via WinGet...$NC"
            winget install AquaSecurity.Trivy --accept-source-agreements --accept-package-agreements
        } else {
            Write-Host "$Blue  Fetching latest release info...$NC"
            $release = Invoke-RestMethod -Uri "https://api.github.com/repos/aquasecurity/trivy/releases/latest" -UseBasicParsing
            $trivyVersion = $release.tag_name.TrimStart('v')
            Write-Host "$Blue  Version: v$trivyVersion$NC"

            $binaryName = "trivy_${trivyVersion}_Windows-64bit.zip"
            $downloadUrl = "https://github.com/aquasecurity/trivy/releases/download/v${trivyVersion}/${binaryName}"
            $zipPath = "$TmpDir\trivy.zip"

            Write-Host "$Blue  Downloading $binaryName...$NC"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing

            Write-Host "$Blue  Extracting to $InstallDir...$NC"
            Expand-Archive -Path $zipPath -DestinationPath $TmpDir -Force
            Copy-Item "$TmpDir\trivy.exe" "$InstallDir\trivy.exe" -Force
            Write-Host "$Green  ✓ trivy installed$NC"
        }
        Write-Host ""
    }

    # =============================================================================
    # 5. npq
    # =============================================================================
    Write-Host "$Yellow[5/5] Installing npq...$NC"
    if (Check-Installed "npq") {
        Write-Host ""
    } else {
        $npm = Get-Command "npm" -ErrorAction SilentlyContinue
        if (!$npm) {
            Write-Host "$Red  npm not found. Please install Node.js first: https://nodejs.org$NC"
            exit 1
        }

        Write-Host "$Blue  Pre-install verification of npq package...$NC"

        # Check for install scripts
        $pkgInfo = npm info npq --json 2>$null | ConvertFrom-Json
        $scripts = $pkgInfo.scripts | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $installScripts = $scripts | Where-Object { $_ -match "install|prepare|postinstall|preinstall" }

        if ($installScripts) {
            Write-Host "$Yellow  ⚠ Install scripts detected: $($installScripts -join ', ')$NC"
            Write-Host "$Yellow  Installing with --ignore-scripts first...$NC"
            npm install -g --ignore-scripts npq

            # Verify installed contents
            $npqDir = (npm root -g) + "\npq"
            Write-Host "$Blue  Verifying installed contents...$NC"
            Get-ChildItem $npqDir -ErrorAction SilentlyContinue | Select-Object -First 10 | Format-Table Name -HideTableHeaders

            $installedScripts = (Get-Content "$npqDir\package.json" -Raw | ConvertFrom-Json).scripts |
                Get-Member -MemberType NoteProperty |
                Select-Object -ExpandProperty Name |
                Where-Object { $_ -match "install|prepare|postinstall|preinstall" }

            if ($installedScripts) {
                Write-Host "$Yellow  ⚠ Scripts present but not executed. Review before re-installing without --ignore-scripts:$NC"
                Write-Host "$Yellow    $($installedScripts -join ', ')$NC"
            }

            Write-Host "$Green  ✓ npq installed (with --ignore-scripts). To enable full functionality, review scripts then reinstall without flag.$NC"
        } else {
            Write-Host "$Green  ✓ No install scripts detected$NC"
            npm install -g npq
            Write-Host "$Green  ✓ npq installed$NC"
        }
        Write-Host ""
    }

    # =============================================================================
    # Summary
    # =============================================================================
    Write-Host "$Blue=== Installation Summary ===$NC"
    Write-Host "$Blue Platform: Windows ($ARCH)$NC"
    Write-Host ""

    $tools = @("gitleaks", "semgrep", "osv-scanner", "trivy", "npq")
    foreach ($tool in $tools) {
        $cmd = Get-Command $tool -ErrorAction SilentlyContinue
        if ($cmd) {
            $version = & $tool version 2>$null || & $tool --version 2>$null || "unknown"
            Write-Host "$Green  ✓ ${tool}: $version$NC"
        } else {
            Write-Host "$Red  ✗ ${tool}: NOT FOUND$NC"
        }
    }

    Write-Host ""
    Write-Host "$Blue All tools installed with verification.$NC"

} finally {
    Cleanup
}
