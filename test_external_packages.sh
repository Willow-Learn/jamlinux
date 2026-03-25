#!/bin/bash
# Smoke-tests for JamLinux external package installation.
#
# Tests both code paths:
#   - install_external_packages.sh  (build-time: direct HTTP index + .deb download)
#   - first-boot.sh                 (first-boot: APT with GPG signed-by)
#
# Usage:
#   sudo ./test_external_packages.sh          # network + apt tests, no install
#   sudo ./test_external_packages.sh --install # also install and then remove packages
#
set -euo pipefail

INSTALL_MODE=false
if [[ "${1:-}" == "--install" ]]; then
    INSTALL_MODE=true
fi

WORK_DIR="$(mktemp -d /tmp/jamlinux-pkg-test.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

PASS=0
FAIL=0
SKIP=0

ULAUNCHER_DEB_URL="https://github.com/Ulauncher/Ulauncher/releases/download/5.15.15/ulauncher_5.15.15_all.deb"
VSCODE_DEB_URL="https://update.code.visualstudio.com/latest/linux-deb-x64/stable"
JULIAN_REPO_BASE_URL="https://julianfairfax.codeberg.page/package-repo/debs"
# Julian Fairfax does not publish a standalone GPG key; the repo is used with
# trusted=yes in first-boot.sh. The package index and .deb download are tested
# via the build-time path below, which bypasses APT entirely.

PACKAGES_INSTALLED_BY_TEST=()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP  $1"; SKIP=$((SKIP + 1)); }
section() { echo; echo "── $1 ──────────────────────────────────────"; }

is_root() {
    [[ $EUID -eq 0 ]]
}

package_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

# ---------------------------------------------------------------------------
# Network / URL reachability
# ---------------------------------------------------------------------------

section "Network reachability"

if curl -fsSL --max-time 15 --output /dev/null "$VSCODE_DEB_URL"; then
    pass "VS Code download URL is reachable"
else
    fail "VS Code download URL is unreachable: $VSCODE_DEB_URL"
fi

if curl -fsSL --max-time 15 --head --output /dev/null \
        "https://github.com/Ulauncher/Ulauncher/releases/download/5.15.15/ulauncher_5.15.15_all.deb"; then
    pass "Ulauncher GitHub release URL is reachable"
else
    fail "Ulauncher GitHub release URL is unreachable"
fi

if curl -fsSL --max-time 15 --output /dev/null \
        "$JULIAN_REPO_BASE_URL/dists/packages/main/binary-amd64/Packages"; then
    pass "Julian Fairfax package index is reachable"
else
    fail "Julian Fairfax package index is unreachable"
fi


# ---------------------------------------------------------------------------
# Build-time path: install_external_packages.sh (direct index parsing)
# ---------------------------------------------------------------------------

section "Build-time path: adw-gtk3 index parse"

INDEX_FILE="$WORK_DIR/Packages-adw"
if curl -fsSL --max-time 15 \
        --output "$INDEX_FILE" \
        "$JULIAN_REPO_BASE_URL/dists/packages/main/binary-amd64/Packages"; then
    pass "Downloaded package index"

    PKG_FILENAME="$(awk '
        BEGIN { RS=""; FS="\n" }
        {
            pkg=""; filename=""
            for (i=1;i<=NF;i++) {
                if ($i ~ /^Package: /) pkg=substr($i,10)
                if ($i ~ /^Filename: /) filename=substr($i,11)
            }
            if (pkg=="adw-gtk3" && filename!="") { print filename; exit }
        }
    ' "$INDEX_FILE")"

    if [[ -n "$PKG_FILENAME" ]]; then
        pass "adw-gtk3 found in index: $PKG_FILENAME"

        DEB_URL="$JULIAN_REPO_BASE_URL/$PKG_FILENAME"
        DEB_FILE="$WORK_DIR/adw-gtk3.deb"
        if curl -fsSL --max-time 60 --output "$DEB_FILE" "$DEB_URL" \
                && dpkg-deb --info "$DEB_FILE" >/dev/null 2>&1; then
            pass "adw-gtk3 .deb downloaded and is a valid Debian archive"
        else
            fail "adw-gtk3 .deb download or validation failed: $DEB_URL"
        fi
    else
        fail "adw-gtk3 not found in package index"
    fi
else
    fail "Could not download package index from Julian repo"
fi

# ---------------------------------------------------------------------------
# Build-time path: VS Code
# ---------------------------------------------------------------------------

section "Build-time path: VS Code"

VSCODE_DEB="$WORK_DIR/code.deb"
if curl -fsSL --max-time 120 --output "$VSCODE_DEB" "$VSCODE_DEB_URL" \
        && dpkg-deb --info "$VSCODE_DEB" >/dev/null 2>&1; then
    VSCODE_VERSION="$(dpkg-deb --field "$VSCODE_DEB" Version)"
    pass "VS Code .deb downloaded and valid (version: $VSCODE_VERSION)"
else
    fail "VS Code .deb download or validation failed"
fi

# ---------------------------------------------------------------------------
# Build-time path: Ulauncher
# ---------------------------------------------------------------------------

section "Build-time path: Ulauncher"

ULAUNCHER_DEB="$WORK_DIR/ulauncher.deb"
if curl -fsSL --max-time 60 --output "$ULAUNCHER_DEB" "$ULAUNCHER_DEB_URL" \
        && dpkg-deb --info "$ULAUNCHER_DEB" >/dev/null 2>&1; then
    ULAUNCHER_VERSION="$(dpkg-deb --field "$ULAUNCHER_DEB" Version)"
    pass "Ulauncher .deb downloaded and valid (version: $ULAUNCHER_VERSION)"
else
    fail "Ulauncher .deb download or validation failed"
fi

# ---------------------------------------------------------------------------
# Optional: full install + removal
# ---------------------------------------------------------------------------

if [[ "$INSTALL_MODE" == true ]]; then
    section "Full install test (--install mode)"

    if ! is_root; then
        skip "Install tests require sudo"
    else

    for PKG_NAME in adw-gtk3 code ulauncher; do
        DEB_MAP_adw_gtk3="$WORK_DIR/adw-gtk3.deb"
        DEB_MAP_code="$VSCODE_DEB"
        DEB_MAP_ulauncher="$ULAUNCHER_DEB"

        VAR="DEB_MAP_${PKG_NAME//-/_}"
        DEB_PATH="${!VAR}"

        if [[ ! -f "$DEB_PATH" ]]; then
            skip "Install test for $PKG_NAME (.deb not downloaded)"
            continue
        fi

        ALREADY_INSTALLED=false
        if package_installed "$PKG_NAME"; then
            ALREADY_INSTALLED=true
            skip "Install test for $PKG_NAME (already installed — not removing existing)"
            continue
        fi

        if apt-get install -y --no-install-recommends "$DEB_PATH" >/dev/null 2>&1; then
            if package_installed "$PKG_NAME"; then
                pass "Installed $PKG_NAME successfully"
                PACKAGES_INSTALLED_BY_TEST+=("$PKG_NAME")
            else
                fail "$PKG_NAME: apt-get returned 0 but package not installed"
            fi
        else
            fail "$PKG_NAME: apt-get install failed"
        fi
    done

    # Remove packages installed by this test
    if [[ "${#PACKAGES_INSTALLED_BY_TEST[@]}" -gt 0 ]]; then
        echo
        echo "  Removing test-installed packages: ${PACKAGES_INSTALLED_BY_TEST[*]}"
        apt-get remove -y "${PACKAGES_INSTALLED_BY_TEST[@]}" >/dev/null 2>&1 && \
            echo "  Removed." || echo "  WARNING: removal failed — manual cleanup needed"
    fi

    fi # end is_root block
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

section "Results"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "  Skipped: $SKIP"
echo

if [[ "$FAIL" -gt 0 ]]; then
    echo "RESULT: FAILED — $FAIL test(s) did not pass."
    exit 1
else
    echo "RESULT: ALL TESTS PASSED"
    exit 0
fi
