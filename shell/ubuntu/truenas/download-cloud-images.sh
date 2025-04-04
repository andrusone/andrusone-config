#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# download-cloud-images.sh — Fetch Latest Stable ISO Images for Virtualization
#
# Executive Summary:
# This script automates the retrieval of the latest stable ISO images for 
# Ubuntu Server, Ubuntu Desktop, and Rocky Linux. It scans official mirror 
# directories, avoids beta/daily builds, and ensures only the most recent 
# LTS versions are kept on disk. This is ideal for homelab, virtualization, 
# or provisioning environments like TrueNAS Scale where cloud-init or 
# unattended installs are used. Saves time, ensures consistency, and avoids 
# manual download errors.
# -----------------------------------------------------------------------------

DEST_DIR="/mnt/HDD-RZ1-01/HDD-RZ1-ENC-LOCAL-01-CMP/Cloud-Images"
mkdir -p "$DEST_DIR"

log_debug() {
    echo "[DEBUG] $1"
}

cleanup_old_versions() {
    local prefix="$1"
    local keep_file="$2"
    echo "Cleaning up old versions of $prefix..."
    find "$DEST_DIR" -type f -name "${prefix}*" ! -name "$keep_file" -exec rm -v {} \;
}

get_lts_releases() {
    local base_url="$1"
    curl -s -A "Mozilla/5.0" "$base_url" \
        | grep -oP 'href="\K[0-9]{2}\.04(\.[0-9])?(?=/")' \
        | grep -Ev '^25\.04|^23\.04|^21\.04|^19\.04|^17\.04|^15\.04|^13\.04|^11\.04|^10\.04' \
        | sort -Vr | uniq
}

download_ubuntu_server_iso() {
    echo "Checking for latest Ubuntu Server LTS ISO..."
    BASE_URL="https://releases.ubuntu.com/"
    LTS_RELEASES=$(get_lts_releases "$BASE_URL")

    for RELEASE in $LTS_RELEASES; do
        RELEASE_URL="${BASE_URL}${RELEASE}/"
        echo "Probing $RELEASE_URL"

        if ! HTML=$(curl -s -A "Mozilla/5.0" "$RELEASE_URL"); then
            echo "Failed to fetch $RELEASE_URL, skipping..."
            continue
        fi

        ISO_NAME=$(echo "$HTML" | grep -oP 'href="\Kubuntu-[0-9.]+-live-server-amd64\.iso(?=")' | grep -viE 'beta|rc|daily' | sort -Vr | head -n1)

        if [[ -z "$ISO_NAME" ]]; then
            echo "No stable server ISO found in $RELEASE — skipping"
            continue
        fi

        OUTPUT_FILE="$DEST_DIR/ubuntu-server-${RELEASE}.iso"
        DOWNLOAD_URL="${RELEASE_URL}${ISO_NAME}"

        if [[ -f "$OUTPUT_FILE" ]]; then
            echo "Ubuntu Server ISO $ISO_NAME already exists. Skipping."
        else
            echo "Downloading $ISO_NAME..."
            curl -fL -A "Mozilla/5.0" -o "$OUTPUT_FILE" "$DOWNLOAD_URL" || {
                echo "Failed to download $ISO_NAME"
                return 1
            }
            echo "Saved to $OUTPUT_FILE"
            cleanup_old_versions "ubuntu-server-" "$(basename "$OUTPUT_FILE")"
        fi

        return
    done

    echo "No stable Ubuntu Server ISO found."
    return 1
}

download_ubuntu_desktop_iso() {
    echo "Checking for latest Ubuntu Desktop LTS ISO..."
    BASE_URL="https://releases.ubuntu.com/"
    LTS_RELEASES=$(get_lts_releases "$BASE_URL")

    for RELEASE in $LTS_RELEASES; do
        RELEASE_URL="${BASE_URL}${RELEASE}/"
        echo "Probing $RELEASE_URL"

        if ! HTML=$(curl -s -A "Mozilla/5.0" "$RELEASE_URL"); then
            echo "Failed to fetch $RELEASE_URL, skipping..."
            continue
        fi

        ISO_NAME=$(echo "$HTML" | grep -oP 'ubuntu-[0-9]{2}\.04(\.[0-9])?-desktop-amd64\.iso' | grep -viE 'beta|rc|daily' | sort -Vr | head -n1)

        if [[ -z "$ISO_NAME" ]]; then
            echo "No stable desktop ISO found in $RELEASE — skipping"
            continue
        fi

        OUTPUT_FILE="$DEST_DIR/ubuntu-desktop-${RELEASE}.iso"
        DOWNLOAD_URL="${RELEASE_URL}${ISO_NAME}"

        if [[ -f "$OUTPUT_FILE" ]]; then
            echo "Ubuntu Desktop ISO $ISO_NAME already exists. Skipping."
        else
            echo "Downloading $ISO_NAME..."
            curl -fL -A "Mozilla/5.0" -o "$OUTPUT_FILE" "$DOWNLOAD_URL" || {
                echo "Failed to download $ISO_NAME"
                return 1
            }
            echo "Saved to $OUTPUT_FILE"
            cleanup_old_versions "ubuntu-desktop-" "$(basename "$OUTPUT_FILE")"
        fi

        return
    done

    echo "No stable Ubuntu Desktop ISO found."
    return 1
}

download_rocky_linux_iso() {
    echo "Checking for latest Rocky Linux ISO..."
    BASE_URL="https://download.rockylinux.org/pub/rocky"
    VERSION=$(curl -s "$BASE_URL/" | grep -oP 'href="\K[0-9]+\.[0-9]+(?=/")' | sort -Vr | head -n1)
    ARCH="x86_64"
    ISO_PATH=$(curl -s "$BASE_URL/$VERSION/isos/$ARCH/" | grep -oP 'href="\KRocky-[^"]+-minimal\.iso(?=")' | sort -Vr | head -n1)
    ISO_URL="${BASE_URL}/${VERSION}/isos/${ARCH}/${ISO_PATH}"
    OUTPUT_FILE="$DEST_DIR/rocky-${VERSION}.iso"

    if [[ -f "$OUTPUT_FILE" ]]; then
        echo "Rocky Linux $VERSION ISO already exists. Skipping."
    else
        echo "Downloading $ISO_PATH..."
        curl -fL -o "$OUTPUT_FILE" "$ISO_URL"
        echo "Saved to $OUTPUT_FILE"
        cleanup_old_versions "rocky-" "$(basename "$OUTPUT_FILE")"
    fi
}

main() {
    echo "Starting ISO download process..."
    download_rocky_linux_iso
    download_ubuntu_server_iso
    download_ubuntu_desktop_iso
    echo "All ISO downloads complete."
}

main
