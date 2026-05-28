#!/usr/bin/env bash

set -euo pipefail

# Configuration
DXVK_REPO="https://gitlab.com/Ph42oN/dxvk-gplasync.git"
DXVK_VERSION="${DXVK_VERSION:-main}" # Defaults to main branch if not specified
SRC_DIR="dxvk-src"
OUT_DIR="out"
ROOT_DIR="$(pwd)"

echo "=== DXVK-gplasync Build Automation for Winlator Bionic ==="
echo "Target DXVK Version/Branch: ${DXVK_VERSION}"

# Clean previous build directories
echo "Cleaning output directories..."
rm -rf "${OUT_DIR}"
rm -rf "${SRC_DIR}"

# Clone source repository
echo "Cloning DXVK-gplasync repository..."
git clone --recursive --depth 1 --branch "${DXVK_VERSION}" "${DXVK_REPO}" "${SRC_DIR}"

# Helper function to build a specific target
compile_target() {
    local target_name=$1
    local cross_file=$2
    local build_dir="${SRC_DIR}/build.${target_name}"
    local dest_dir="${OUT_DIR}/dlls/${target_name}"

    echo "--- Building ${target_name} ---"
    cd "${SRC_DIR}"
    
    # Run meson setup
    meson setup \
        --cross-file "${ROOT_DIR}/${cross_file}" \
        --buildtype release \
        --strip \
        "${build_dir}"
    
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

# 1. Compile standard 32-bit (x86) target
compile_target "x86" "cross-x86.ini"

# 2. Compile standard 64-bit (x64) target
compile_target "x64" "cross-x64.ini"

# 3. Compile ARM64EC (Emulation Compatible) target
compile_target "arm64ec" "cross-arm64ec.ini"

# Packaging
echo "=== Packaging Winlator Component Packages (.wcp) ==="

# Helper function to create WCP package
create_wcp() {
    local package_name=$1
    local profile_file=$2
    local sys32_dll_dir=$3
    local syswow64_dll_dir=$4
    local wcp_dir="${OUT_DIR}/wcp-${package_name}"

    echo "Packaging ${package_name}..."
    mkdir -p "${wcp_dir}"
    
    # Copy profile.json
    cp "${profile_file}" "${wcp_dir}/profile.json"
    
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
