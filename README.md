# DXVK-gplasync Winlator Bionic Build Automation

This repository provides automated GitHub Actions workflows to compile and package **DXVK-gplasync** (from Ph42oN's repository) specifically for **Winlator Bionic** environments. It supports building both standard (x86/x64) and ARM64EC architectures, packaged in the `.wcp` (Winlator Component Package) format.

---

## Component Layout

Inside the `.wcp` files, the DLLs are organized as follows to support standard and ARM64EC environments:

### 1. Standard Build (`dxvk-gplasync-standard.wcp`)
Designed for standard containers where games are emulated under x86 or x86_64 architecture:
- `system32/`: Contains standard 64-bit (x64) DXVK DLLs.
- `syswow64/`: Contains standard 32-bit (x86) DXVK DLLs.

### 2. ARM64EC Build (`dxvk-gplasync-arm64ec.wcp`)
Designed for containers running **FEXCore** (specifically configured for ARM64EC):
- `system32/`: Contains native 64-bit **ARM64EC** DXVK DLLs (providing high native graphics performance on ARM64 processors without x64 translation overhead).
- `syswow64/`: Contains standard 32-bit (x86) DXVK DLLs to maintain compatibility for 32-bit games.

---

## File Structure

- [`.github/workflows/build.yml`](.github/workflows/build.yml): The GitHub Actions build automation script.
- [`cross-x86.ini`](cross-x86.ini): Meson cross file for standard x86 compilation.
- [`cross-x64.ini`](cross-x64.ini): Meson cross file for standard x64 compilation.
- [`cross-arm64ec.ini`](cross-arm64ec.ini): Meson cross file for ARM64EC compilation.
- [`profile-standard.json`](profile-standard.json): Manifest for standard WCP package.
- [`profile-arm64ec.json`](profile-arm64ec.json): Manifest for ARM64EC WCP package.
- [`build.sh`](build.sh): Bash script to automate building and packaging locally or on the CI runner.

---

## How to Trigger the Build

The build pipeline is designed to be triggered manually or automatically on pushes to the `main` or `master` branch.

### Manual Build via GitHub Actions
1. Go to the **Actions** tab in your GitHub repository.
2. Select **DXVK GPLAsync Build Automation** from the sidebar.
3. Click the **Run workflow** dropdown.
4. Input the specific target version/tag or branch of `dxvk-gplasync` (e.g. `v2.7.1-1`, `v2.7-1`, or `master`).
5. Click **Run workflow**.

Once complete, the workflow will:
1. Compile all targets using `llvm-mingw`.
2. Generate the standard and ARM64EC `.wcp` packages.
3. Publish a new GitHub Release with the `.wcp` packages attached as release assets.
4. Upload them as workflow artifacts for immediate download.

---

## How to Install in Winlator
1. Download the `.wcp` file (e.g. `dxvk-gplasync-standard.wcp` or `dxvk-gplasync-arm64ec.wcp`) from the Releases page of your repository.
2. Open Winlator on your Android device.
3. Go to settings/menu and locate the **Install Content** or **Add-ons/Components** manager.
4. Select the downloaded `.wcp` file.
5. Winlator will automatically extract the DLLs into the appropriate Wine prefix directories (`system32` and `syswow64`) using the included manifest.
6. In your Winlator container settings, select the newly imported DXVK version.