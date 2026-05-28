#!/usr/bin/env bash

set -euo pipefail

# Configuration
PATCH_REPO="https://gitlab.com/Ph42oN/dxvk-gplasync.git"
DXVK_VERSION="${DXVK_VERSION:-main}" # Defaults to main branch if not specified
SRC_DIR="dxvk-src"
PATCH_DIR="patches-repo"
OUT_DIR="out"
ROOT_DIR="$(pwd)"

echo "=== DXVK-gplasync Build Automation for Winlator Bionic ==="
echo "Target DXVK Version Input: ${DXVK_VERSION}"

# Clean previous build directories
echo "Cleaning output directories..."
rm -rf "${OUT_DIR}"
rm -rf "${SRC_DIR}"
rm -rf "${PATCH_DIR}"

# 1. Clone patch repository
echo "Cloning dxvk-gplasync patch repository..."
git clone --depth 1 "${PATCH_REPO}" "${PATCH_DIR}"

# 2. Determine target version and patches to apply
if [ "${DXVK_VERSION}" = "main" ] || [ "${DXVK_VERSION}" = "master" ]; then
    echo "Autodetecting latest patch version..."
    LATEST_PATCH_FILE=$(ls -1 "${PATCH_DIR}/patches"/dxvk-gplasync-[0-9]*.patch | sort -V | tail -n 1)
    PATCH_NAME=$(basename "${LATEST_PATCH_FILE}")
    VERSION_TAG=${PATCH_NAME#dxvk-gplasync-}
    VERSION_TAG=${VERSION_TAG%.patch}
    echo "Autodetected latest version tag: ${VERSION_TAG}"
    DXVK_TAG="v${VERSION_TAG%-*}"
else
    # Parse user-specified version
    VERSION_TAG="${DXVK_VERSION#v}" # remove leading 'v' if present
    if [[ "${VERSION_TAG}" == *-* ]]; then
        DXVK_TAG="v${VERSION_TAG%-*}"
    else
        DXVK_TAG="${VERSION_TAG}"
    fi
fi
echo "Target official DXVK tag: ${DXVK_TAG}"
echo "Target patch: dxvk-gplasync-${VERSION_TAG}.patch"

# 3. Clone official DXVK source code repository
echo "Cloning official DXVK repository..."
git clone --branch "${DXVK_TAG}" --recursive --depth 1 https://github.com/doitsujin/dxvk.git "${SRC_DIR}"

# 4. Apply GPLAsync patches
echo "Applying patches..."
cd "${SRC_DIR}"
patch -p1 < "../${PATCH_DIR}/patches/dxvk-gplasync-${VERSION_TAG}.patch"

# Check if global-dxvk.conf patch exists and apply it
if [ -f "../${PATCH_DIR}/patches/global-dxvk.conf.patch" ]; then
    patch -p1 < "../${PATCH_DIR}/patches/global-dxvk.conf.patch"
fi
cd "${ROOT_DIR}"

# 5. Compile targets
# Helper function to build a specific target
compile_target() {
    local target_name=$1
    local cross_file=$2
    local build_dir="build.${target_name}"
    local dest_dir="${OUT_DIR}/dlls/${target_name}"

    echo "--- Building ${target_name} ---"
    cd "${SRC_DIR}"
    
    # Run meson setup
    meson setup "${build_dir}" --cross-file "${ROOT_DIR}/${cross_file}" --buildtype release --strip
    
    # Build DLLs
    ninja -C "${build_dir}"
    cd "${ROOT_DIR}"

    # Collect DLLs
    echo "Collecting DLLs to ${dest_dir}..."
    mkdir -p "${dest_dir}"
    cp "${SRC_DIR}/${build_dir}/src/d3d9/d3d9.dll" "${dest_dir}/"
    cp "${SRC_DIR}/${build_dir}/src/d3d10/d3d10core.dll" "${dest_dir}/"
    cp "${SRC_DIR}/${build_dir}/src/d3d11/d3d11.dll" "${dest_dir}/"
    cp "${SRC_DIR}/${build_dir}/src/dxgi/dxgi.dll" "${dest_dir}/"
}

# Compile standard 32-bit (x86) target
compile_target "x86" "cross-x86.ini"

# Compile standard 64-bit (x64) target
compile_target "x64" "cross-x64.ini"

# Compile ARM64EC (Emulation Compatible) target
compile_target "arm64ec" "cross-arm64ec.ini"

# Packaging
# Helper function to create WCP package
create_wcp() {
    local package_name=$1
    local profile_file=$2
    local sys32_dll_dir=$3
    local syswow64_dll_dir=$4
    local wcp_dir="${OUT_DIR}/wcp-${package_name}"

    echo "Packaging ${package_name}..."
    mkdir -p "${wcp_dir}"
    
    # Copy profile.json and dynamically update version metadata using jq
    local display_ver="v${VERSION_TAG}"
    if [ "${package_name}" = "arm64ec" ]; then
        display_ver="${display_ver}-arm64ec"
    fi
    jq --arg ver "${display_ver}" '.version = $ver' "${profile_file}" > "${wcp_dir}/profile.json"
    
    # Copy DLLs
    mkdir -p "${wcp_dir}/system32"
    mkdir -p "${wcp_dir}/syswow64"
    cp "${OUT_DIR}/dlls/${sys32_dll_dir}"/*.dll "${wcp_dir}/system32/"
    cp "${OUT_DIR}/dlls/${syswow64_dll_dir}"/*.dll "${wcp_dir}/syswow64/"

    # Compress into .wcp file (tar + zstd)
    cd "${wcp_dir}"
    tar -cf - profile.json system32 syswow64 | zstd -9 -o "${ROOT_DIR}/${OUT_DIR}/dxvk-gplasync-${package_name}.wcp"
    cd "${ROOT_DIR}"
    
    echo "Successfully created: ${OUT_DIR}/dxvk-gplasync-${package_name}.wcp"
}

# Create standard package (system32 -> x64, syswow64 -> x86)
create_wcp "standard" "profile-standard.json" "x64" "x86"

# Create arm64ec package (system32 -> arm64ec, syswow64 -> x86)
create_wcp "arm64ec" "profile-arm64ec.json" "arm64ec" "x86"

echo "=== Build and Packaging Complete! ==="
ls -l "${OUT_DIR}"/*.wcp
