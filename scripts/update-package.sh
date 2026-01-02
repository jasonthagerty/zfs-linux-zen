#!/bin/bash
# Automated package update script for zfs-linux-zen
# This script checks for new versions of linux-zen kernel and OpenZFS,
# then updates the PKGBUILD accordingly.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PKGBUILD_PATH="$REPO_ROOT/PKGBUILD"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get current versions from PKGBUILD
get_current_zfs_version() {
    grep -oP '_zfsver="\K[^"]+' "$PKGBUILD_PATH"
}

get_current_kernel_version() {
    grep -oP '_kernelver="\K[^"]+' "$PKGBUILD_PATH"
}

# Get latest linux-zen kernel version from Arch repos
get_latest_kernel_version() {
    # Query Arch Linux official repos API
    local response
    response=$(curl -s 'https://archlinux.org/packages/extra/x86_64/linux-zen/json/')

    if [ -z "$response" ]; then
        log_error "Failed to fetch kernel version from Arch repos"
        return 1
    fi

    # Extract pkgver and pkgrel, format as pkgver-pkgrel
    local pkgver pkgrel
    pkgver=$(echo "$response" | jq -r '.pkgver')
    pkgrel=$(echo "$response" | jq -r '.pkgrel')

    if [ "$pkgver" = "null" ] || [ "$pkgrel" = "null" ]; then
        log_error "Failed to parse kernel version"
        return 1
    fi

    echo "${pkgver}-${pkgrel}"
}

# Get latest OpenZFS release from GitHub
get_latest_zfs_version() {
    local response
    response=$(curl -s 'https://api.github.com/repos/openzfs/zfs/releases/latest')

    if [ -z "$response" ]; then
        log_error "Failed to fetch ZFS version from GitHub"
        return 1
    fi

    # Extract tag name and remove 'zfs-' prefix
    local version
    version=$(echo "$response" | jq -r '.tag_name' | sed 's/^zfs-//')

    if [ "$version" = "null" ] || [ -z "$version" ]; then
        log_error "Failed to parse ZFS version"
        return 1
    fi

    echo "$version"
}

# Download ZFS tarball and calculate sha256sum
get_zfs_sha256() {
    local version="$1"
    local url="https://github.com/openzfs/zfs/releases/download/zfs-${version}/zfs-${version}.tar.gz"
    local tmp_file
    tmp_file=$(mktemp)

    if ! curl -L -s -o "$tmp_file" "$url"; then
        log_error "Failed to download ZFS tarball"
        rm -f "$tmp_file"
        return 1
    fi

    local checksum
    checksum=$(sha256sum "$tmp_file" | awk '{print $1}')
    rm -f "$tmp_file"

    echo "$checksum"
}

# Update PKGBUILD with new versions
update_pkgbuild() {
    local new_zfs_version="$1"
    local new_kernel_version="$2"
    local new_sha256="$3"

    log_info "Updating PKGBUILD..."

    # Create backup
    cp "$PKGBUILD_PATH" "${PKGBUILD_PATH}.bak"

    # Update versions using sed
    sed -i "s/_zfsver=\"[^\"]*\"/_zfsver=\"${new_zfs_version}\"/" "$PKGBUILD_PATH"
    sed -i "s/_kernelver=\"[^\"]*\"/_kernelver=\"${new_kernel_version}\"/" "$PKGBUILD_PATH"
    sed -i "s/_kernelver_full=\"[^\"]*\"/_kernelver_full=\"${new_kernel_version}\"/" "$PKGBUILD_PATH"
    sed -i "s/sha256sums=(\"[^\"]*\")/sha256sums=(\"${new_sha256}\")/" "$PKGBUILD_PATH"

    # Reset pkgrel to 1 for new version
    sed -i "s/pkgrel=.*/pkgrel=1/" "$PKGBUILD_PATH"

    log_info "PKGBUILD updated successfully"
}

# Generate .SRCINFO
generate_srcinfo() {
    log_info "Generating .SRCINFO..."

    cd "$REPO_ROOT"

    # Check if makepkg is available
    if ! command -v makepkg &> /dev/null; then
        log_warn "makepkg not found, cannot generate .SRCINFO"
        log_warn "You may need to install pacman/makepkg or generate .SRCINFO manually"
        return 0
    fi

    makepkg --printsrcinfo > .SRCINFO
    log_info ".SRCINFO generated successfully"
}

# Main update logic
main() {
    log_info "Starting package update check..."

    # Get current versions
    local current_zfs current_kernel
    current_zfs=$(get_current_zfs_version)
    current_kernel=$(get_current_kernel_version)

    log_info "Current ZFS version: $current_zfs"
    log_info "Current kernel version: $current_kernel"

    # Get latest versions
    log_info "Checking for latest versions..."
    local latest_zfs latest_kernel
    latest_zfs=$(get_latest_zfs_version)
    latest_kernel=$(get_latest_kernel_version)

    log_info "Latest ZFS version: $latest_zfs"
    log_info "Latest kernel version: $latest_kernel"

    # Check if update is needed
    local needs_update=false
    local update_reason=""

    if [ "$current_zfs" != "$latest_zfs" ]; then
        needs_update=true
        update_reason="ZFS: $current_zfs → $latest_zfs"
    fi

    if [ "$current_kernel" != "$latest_kernel" ]; then
        if [ "$needs_update" = true ]; then
            update_reason="$update_reason, Kernel: $current_kernel → $latest_kernel"
        else
            update_reason="Kernel: $current_kernel → $latest_kernel"
        fi
        needs_update=true
    fi

    if [ "$needs_update" = false ]; then
        log_info "Package is up to date!"
        echo "UP_TO_DATE=true" >> "${GITHUB_OUTPUT:-/dev/null}"
        return 0
    fi

    log_info "Update needed: $update_reason"

    # If ZFS version changed, get new checksum
    local new_sha256
    if [ "$current_zfs" != "$latest_zfs" ]; then
        log_info "Downloading ZFS ${latest_zfs} tarball to calculate checksum..."
        new_sha256=$(get_zfs_sha256 "$latest_zfs")
        log_info "New SHA256: $new_sha256"
    else
        # Keep existing checksum if ZFS version didn't change
        new_sha256=$(grep -oP 'sha256sums=\("\K[^"]+' "$PKGBUILD_PATH")
    fi

    # Update PKGBUILD
    update_pkgbuild "$latest_zfs" "$latest_kernel" "$new_sha256"

    # Generate .SRCINFO
    generate_srcinfo

    # Output for GitHub Actions
    if [ -n "${GITHUB_OUTPUT:-}" ]; then
        echo "UPDATED=true" >> "$GITHUB_OUTPUT"
        echo "ZFS_VERSION=$latest_zfs" >> "$GITHUB_OUTPUT"
        echo "KERNEL_VERSION=$latest_kernel" >> "$GITHUB_OUTPUT"
        echo "UPDATE_REASON=$update_reason" >> "$GITHUB_OUTPUT"
    fi

    log_info "Update completed successfully!"
    log_info "Update summary: $update_reason"
}

# Run main function
main "$@"
