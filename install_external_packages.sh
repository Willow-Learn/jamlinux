#!/bin/bash
set -eu

export DEBIAN_FRONTEND=noninteractive

download_dir="/var/tmp/jamlinux-external-packages"
deb_cache_dir="/var/lib/jamlinux/external-debs"
ulauncher_deb_url="https://github.com/Ulauncher/Ulauncher/releases/download/5.15.15/ulauncher_5.15.15_all.deb"
vscode_deb_url="https://update.code.visualstudio.com/latest/linux-deb-x64/stable"
julian_repo_base_url="https://julianfairfax.codeberg.page/package-repo/debs"
max_attempts="${JAMLINUX_EXTERNAL_RETRY_ATTEMPTS:-4}"
initial_retry_delay="${JAMLINUX_EXTERNAL_RETRY_DELAY:-10}"
# Build-time installs should fail loudly if these packages cannot be staged.
strict_mode="${JAMLINUX_EXTERNAL_STRICT:-1}"

log() {
    echo "[jamlinux external packages] $*"
}

refresh_certificates() {
    if command -v update-ca-certificates >/dev/null 2>&1; then
        update-ca-certificates >/dev/null 2>&1 || true
    fi
}

package_installed() {
    local package_name="$1"

    dpkg-query -W -f='${Status}' "$package_name" 2>/dev/null | grep -q "install ok installed"
}

run_with_retries() {
    local description="$1"
    shift

    local attempt=1
    local delay="$initial_retry_delay"

    while [ "$attempt" -le "$max_attempts" ]; do
        refresh_certificates

        if "$@"; then
            if [ "$attempt" -gt 1 ]; then
                log "$description succeeded on attempt $attempt/$max_attempts."
            fi
            return 0
        fi

        if [ "$attempt" -eq "$max_attempts" ]; then
            log "$description failed after $attempt attempts."
            return 1
        fi

        log "$description failed on attempt $attempt/$max_attempts; retrying in ${delay}s."
        sleep "$delay"

        attempt=$((attempt + 1))
        delay=$((delay * 2))
    done
}

repo_update() {
    local list_dest="$1"

    apt-get update \
        -o Dir::Etc::sourcelist="$list_dest" \
        -o Dir::Etc::sourceparts="-" \
        -o APT::Get::List-Cleanup="0"
}

default_repo_update() {
    apt-get update
}

repo_install() {
    local package_name="$1"

    apt-get install -y --no-install-recommends "$package_name"
}

download_file() {
    local url="$1"
    local destination="$2"

    curl -fsSL --retry 3 --retry-all-errors --output "$destination" "$url"
}

install_local_deb() {
    local deb_path="$1"

    apt-get install -y --no-install-recommends "$deb_path"
}

cache_deb() {
    local deb_path="$1"
    local filename

    filename="$(basename "$deb_path")"
    mkdir -p "$deb_cache_dir"
    cp "$deb_path" "$deb_cache_dir/$filename"
    log "Cached $filename for installed-system provisioning."
}

download_packages_index() {
    local base_url="$1"
    local suite="$2"
    local component="$3"
    local architecture="$4"
    local output_file="$5"
    local index_base="$base_url/dists/$suite/$component/binary-$architecture/Packages"
    local tmp_archive

    tmp_archive="$(mktemp)"

    if curl -fsSL --retry 3 --retry-all-errors --output "$output_file" "$index_base"; then
        rm -f "$tmp_archive"
        return 0
    fi

    if command -v gzip >/dev/null 2>&1; then
        if curl -fsSL --retry 3 --retry-all-errors --output "$tmp_archive" "$index_base.gz"; then
            gzip -dc "$tmp_archive" > "$output_file"
            rm -f "$tmp_archive"
            return 0
        fi
    fi

    if command -v xz >/dev/null 2>&1; then
        if curl -fsSL --retry 3 --retry-all-errors --output "$tmp_archive" "$index_base.xz"; then
            xz -dc "$tmp_archive" > "$output_file"
            rm -f "$tmp_archive"
            return 0
        fi
    fi

    rm -f "$tmp_archive"
    return 1
}

find_deb_filename_in_index() {
    local package_name="$1"
    local architecture="$2"
    local index_file="$3"

    awk -v package_name="$package_name" -v architecture="$architecture" '
        BEGIN {
            RS=""
            FS="\n"
        }
        {
            pkg=""
            arch=""
            filename=""

            for (i = 1; i <= NF; i++) {
                if ($i ~ /^Package: /) {
                    pkg = substr($i, 10)
                } else if ($i ~ /^Architecture: /) {
                    arch = substr($i, 15)
                } else if ($i ~ /^Filename: /) {
                    filename = substr($i, 11)
                }
            }

            if (pkg == package_name && (arch == architecture || arch == "all") && filename != "") {
                print filename
                exit
            }
        }
    ' "$index_file"
}

install_deb_from_url() {
    local name="$1"
    local package_name="$2"
    local deb_url="$3"
    local deb_path="$download_dir/$package_name.deb"

    if package_installed "$package_name"; then
        log "$package_name is already installed."
        return 0
    fi

    if ! run_with_retries "APT metadata refresh for $name dependencies" default_repo_update; then
        log "Skipping $package_name: failed to refresh APT metadata for dependencies."
        return 1
    fi

    if run_with_retries "$name package download" download_file "$deb_url" "$deb_path"; then
        cache_deb "$deb_path"

        if run_with_retries "$name package install" install_local_deb "$deb_path"; then
            log "Installed $package_name from a pinned .deb package."
            rm -f "$deb_path"
            return 0
        fi

        log "Skipping $package_name: install from the pinned .deb failed."
        return 1
    fi

    log "Skipping $package_name: download failed."
    return 1
}

install_deb_from_repo_index() {
    local name="$1"
    local package_name="$2"
    local architecture="$3"
    local base_url="$4"
    local suite="$5"
    local component="$6"
    local index_path="$download_dir/${package_name}.Packages"
    local relative_deb_path
    local deb_url
    local deb_path="$download_dir/$package_name.deb"

    if package_installed "$package_name"; then
        log "$package_name is already installed."
        return 0
    fi

    if ! run_with_retries "APT metadata refresh for $name dependencies" default_repo_update; then
        log "Skipping $package_name: failed to refresh APT metadata for dependencies."
        return 1
    fi

    if ! run_with_retries "$name package index download" download_packages_index "$base_url" "$suite" "$component" "$architecture" "$index_path"; then
        log "Skipping $package_name: could not fetch package index from $base_url."
        return 1
    fi

    relative_deb_path="$(find_deb_filename_in_index "$package_name" "$architecture" "$index_path")"
    if [ -z "$relative_deb_path" ]; then
        log "Skipping $package_name: package entry was not found in downloaded index."
        rm -f "$index_path"
        return 1
    fi

    deb_url="$base_url/$relative_deb_path"

    if run_with_retries "$name package download" download_file "$deb_url" "$deb_path"; then
        cache_deb "$deb_path"

        if run_with_retries "$name package install" install_local_deb "$deb_path"; then
            log "Installed $package_name from $base_url package index."
            rm -f "$index_path" "$deb_path"
            return 0
        fi

        log "Skipping $package_name: install from downloaded .deb failed."
        rm -f "$index_path"
        return 1
    fi

    log "Skipping $package_name: package download failed from $deb_url."
    rm -f "$index_path"
    return 1
}

install_ulauncher_release() {
    local deb_path="$download_dir/ulauncher_5.15.15_all.deb"

    if package_installed ulauncher; then
        log "ulauncher is already installed."
        return 0
    fi

    mkdir -p "$download_dir"

    if ! run_with_retries "APT metadata refresh for Ulauncher dependencies" default_repo_update; then
        log "Skipping ulauncher: failed to refresh APT metadata for dependencies."
        return 1
    fi

    if run_with_retries "Ulauncher release download" download_file "$ulauncher_deb_url" "$deb_path"
    then
        cache_deb "$deb_path"

        if run_with_retries "Ulauncher package install" install_local_deb "$deb_path"; then
            log "Installed ulauncher from the pinned GitHub release package."
            rm -f "$deb_path"
        else
            log "Skipping ulauncher: install from the pinned GitHub release failed."
            return 1
        fi
    else
        log "Skipping ulauncher: download from the pinned GitHub release failed."
        return 1
    fi
}

required_packages="code adw-gtk3 ulauncher"
failures=0

mkdir -p "$download_dir"

install_deb_from_url "VS Code" "code" "$vscode_deb_url" || failures=1
install_deb_from_repo_index "Julian package repo" "adw-gtk3" "amd64" "$julian_repo_base_url" "packages" "main" || failures=1
install_ulauncher_release || failures=1

# Post-install verification: confirm every required package is installed and
# its .deb is cached for the offline installer payload, regardless of what
# the install functions reported.  This catches subtle edge cases (e.g. an
# install command returning 0 without actually installing the package, or the
# .deb cache copy failing silently).
for pkg in $required_packages; do
    if ! package_installed "$pkg"; then
        log "VERIFICATION FAILED: $pkg is not installed."
        failures=1
    fi
done

cached_count="$(find "$deb_cache_dir" -maxdepth 1 -name "*.deb" -type f 2>/dev/null | wc -l)"
expected_count="$(echo "$required_packages" | wc -w)"
if [ "$cached_count" -lt "$expected_count" ]; then
    log "VERIFICATION FAILED: Expected $expected_count cached .deb files in $deb_cache_dir but found $cached_count."
    failures=1
else
    log "Verified: $cached_count .deb files cached in $deb_cache_dir."
fi

if [ "$failures" -ne 0 ]; then
    log "One or more external packages could not be installed or verified."
    if [ "$strict_mode" -eq 1 ]; then
        exit 1
    fi
fi
