#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${BASH_SOURCE[0]}"
ASSETS_DIR="${SCRIPT_DIR}/assets"
CHECKPOINT_DIR="${HOME}/.cache/omcachy-install"
mkdir -p "$CHECKPOINT_DIR"

# ─── Version check: invalidate checkpoints if script has changed ─────────────
SCRIPT_HASH="$(sha256sum "$SCRIPT_PATH" | awk '{print $1}')"
if [ -f "${CHECKPOINT_DIR}/script_hash" ]; then
    SAVED_HASH="$(cat "${CHECKPOINT_DIR}/script_hash")"
    if [ "$SCRIPT_HASH" != "$SAVED_HASH" ]; then
        echo "Script has been modified since last run. Clearing checkpoints and starting fresh..."
        rm -rf "$CHECKPOINT_DIR"
        mkdir -p "$CHECKPOINT_DIR"
    fi
fi
echo "$SCRIPT_HASH" > "${CHECKPOINT_DIR}/script_hash"

# ─── Restore or create the temporary working directory ────────────────────────
if [ -f "${CHECKPOINT_DIR}/work_dir" ]; then
    SAVED_WORK_DIR="$(cat "${CHECKPOINT_DIR}/work_dir")"
    if [ -d "$SAVED_WORK_DIR" ]; then
        WORK_DIR="$SAVED_WORK_DIR"
        echo "Resuming with temporary working directory: ${WORK_DIR}"
    else
        echo "Previous working directory (${SAVED_WORK_DIR}) no longer exists."
        echo "Clearing stale checkpoints and starting fresh..."
        rm -rf "$CHECKPOINT_DIR"
        mkdir -p "$CHECKPOINT_DIR"
        echo "$SCRIPT_HASH" > "${CHECKPOINT_DIR}/script_hash"
        WORK_DIR="$(mktemp -d /tmp/omcachy-install.XXXXXX)"
        echo "$WORK_DIR" > "${CHECKPOINT_DIR}/work_dir"
        echo "Using new temporary working directory: ${WORK_DIR}"
    fi
else
    WORK_DIR="$(mktemp -d /tmp/omcachy-install.XXXXXX)"
    echo "$WORK_DIR" > "${CHECKPOINT_DIR}/work_dir"
    echo "Using temporary working directory: ${WORK_DIR}"
fi

REPO_DIR="${WORK_DIR}/omarchy"

# Clean up temp directory on exit (success or failure)
cleanup() {
    echo ""
    echo "Cleaning up temporary directory: ${WORK_DIR}"
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

checkpoint_done() {
    [ -f "${CHECKPOINT_DIR}/$1" ]
}

checkpoint_set() {
    touch "${CHECKPOINT_DIR}/$1"
}

# ─── 1. Check if git is installed ────────────────────────────────────────────
if ! command -v git &> /dev/null; then
    echo "Error: git is not installed. Please install git before running this script."
    exit 1
fi

# ─── 2. Check if paru is installed ───────────────────────────────────────────
if ! command -v paru &> /dev/null; then
    echo "Error: paru is not installed. It should be pre-installed on CachyOS."
    echo "Install it with: sudo pacman -S paru"
    exit 1
fi
echo "[✓] paru is installed."

# ─── 3. Clone Omarchy repo ───────────────────────────────────────────────────
if ! checkpoint_done "clone"; then
    if [ -d "$REPO_DIR" ]; then
        echo "Omarchy directory already exists, skipping clone."
    else
        echo "Cloning Omarchy from repo..."
        if ! git clone https://www.github.com/basecamp/omarchy "$REPO_DIR"; then
            echo "Error: Failed to clone Omarchy repo."
            exit 1
        fi
    fi
    checkpoint_set "clone"
else
    echo "[✓] Clone already completed, skipping."
fi

# ─── 4. Rename display text omarchy → omcachy inside files ───────────────────
if ! checkpoint_done "rename"; then
    echo "Renaming display text omarchy → omcachy inside files..."
    echo "  (Preserving upstream package names, commands, paths, URLs, and pacman config)"
    cd "$REPO_DIR"

    find . -not -path './.git/*' -type f -exec sed -i \
      -e '/https:\/\/.*omarchy/!{' \
      -e '/Server\s*=.*omarchy/!{' \
      -e '/\[omarchy\]/!{' \
      -e '/omarchy-/!{' \
      -e '/omarchy\./!{' \
      -e '/\.local\/share\/omarchy/!{' \
      -e '/OMARCHY_/!{' \
      -e '/run_logged.*omarchy/!{' \
      -e '/pacman.*omarchy/!{' \
      -e '/cp.*omarchy/!{' \
      -e '/mkdir.*omarchy/!{' \
      -e 's/OMARCHY/OMCACHY/g' \
      -e 's/Omarchy/Omcachy/g' \
      -e 's/omarchy/omcachy/g' \
      -e '}' \
      -e '}' \
      -e '}' \
      -e '}' \
      -e '}' \
      -e '}' \
      -e '}' \
      -e '}' \
      -e '}' \
      -e '}' \
      -e '}' \
    {} +

    checkpoint_set "rename"
else
    echo "[✓] Rename already completed, skipping."
fi

# ─── 5. Replace branding assets ──────────────────────────────────────────────
if ! checkpoint_done "branding"; then
    echo "Replacing branding assets with custom versions from ${ASSETS_DIR}..."
    cd "$REPO_DIR"

    if [ ! -d "$ASSETS_DIR" ]; then
        echo "  ⚠ Assets directory not found (${ASSETS_DIR}), skipping branding."
    else
        ASSETS=("logo.txt" "logo.svg" "icon.txt" "icon.svg" "icon.png")
        for asset in "${ASSETS[@]}"; do
            src="${ASSETS_DIR}/${asset}"
            if [ ! -f "$src" ]; then
                echo "  ⚠ ${asset} not found in assets directory (${ASSETS_DIR}), skipping."
                continue
            fi

            found=false
            while IFS= read -r -d '' target; do
                cp "$src" "$target"
                echo "  - Replaced ${target}"
                found=true
            done < <(find . -not -path './.git/*' -name "$asset" -print0)

            if [ "$found" = false ]; then
                echo "  ⚠ No instances of ${asset} found in the repo."
            fi
        done
    fi

    checkpoint_set "branding"
else
    echo "[✓] Branding assets already replaced, skipping."
fi

# ─── 6. Import Omarchy signing key ────────────────────────���──────────────────
if ! checkpoint_done "signing_key"; then
    if pacman-key --list-keys F0134EE680CAC571 &> /dev/null; then
        echo "Omarchy signing key already imported."
    else
        echo "Importing Omarchy signing key..."
        sudo pacman-key --recv-keys F0134EE680CAC571
        sudo pacman-key --lsign-key F0134EE680CAC571
    fi
    checkpoint_set "signing_key"
else
    echo "[✓] Signing key step already completed, skipping."
fi

# ─── 7. Add omarchy repo to pacman.conf ──────────────────────────────────────
if ! checkpoint_done "pacman_repo"; then
    if grep -q '^\[omarchy\]' /etc/pacman.conf; then
        echo "Omarchy repo already present in pacman.conf."
    else
        echo "Adding Omarchy repo to pacman.conf..."
        echo -e "\n[omarchy]\nSigLevel = Optional TrustedOnly\nServer = https://pkgs.omarchy.org/\$arch" | sudo tee -a /etc/pacman.conf > /dev/null
    fi
    sudo pacman -Syu --noconfirm
    checkpoint_set "pacman_repo"
else
    echo "[✓] Pacman repo step already completed, skipping."
fi

# ─── 8. Remove CachyOS SDDM config ──────────────────────────────────────────
if ! checkpoint_done "sddm"; then
    if [ -f /etc/sddm.conf ]; then
        echo "Removing /etc/sddm.conf..."
        sudo rm /etc/sddm.conf
    else
        echo "/etc/sddm.conf does not exist, nothing to remove."
    fi
    checkpoint_set "sddm"
else
    echo "[✓] SDDM step already completed, skipping."
fi

# ─── 9. Prompt for user info (only if not already captured) ──────────────────
if ! checkpoint_done "user_info"; then
    echo ""
    echo "Please enter your username:"
    read -r OMCACHY_USER_NAME
    echo "Please enter your email address:"
    read -r OMCACHY_USER_EMAIL

    echo "$OMCACHY_USER_NAME" > "${CHECKPOINT_DIR}/user_name"
    echo "$OMCACHY_USER_EMAIL" > "${CHECKPOINT_DIR}/user_email"
    checkpoint_set "user_info"
else
    OMCACHY_USER_NAME="$(cat "${CHECKPOINT_DIR}/user_name")"
    OMCACHY_USER_EMAIL="$(cat "${CHECKPOINT_DIR}/user_email")"
    echo "[✓] User info already captured (${OMCACHY_USER_NAME} / ${OMCACHY_USER_EMAIL}), skipping."
fi
export OMCACHY_USER_NAME
export OMCACHY_USER_EMAIL

# ─── 10. Patch install scripts for CachyOS ───────────────────────────────────
if ! checkpoint_done "patch_scripts"; then
    echo ""
    echo "Making adjustments to install scripts to support CachyOS..."
    cd "$REPO_DIR"

    # Remove tldr to prevent conflict with tealdeer
    if grep -q 'tldr' install/omarchy-base.packages 2>/dev/null; then
        sed -i '/tldr/d' install/omarchy-base.packages
        echo "  - Removed tldr from packages."
    fi

    # Update restart-needed for cachyos kernel naming
    if ! grep -q 'linux-cachyos' bin/omarchy-update-restart 2>/dev/null; then
        sed -i "s/ | sed 's\/-arch\/\\\.arch\/'//" bin/omarchy-update-restart
        sed -i "s/'{print \$2}'/'{print \$2 \"-\" \$1}' | sed 's\/-linux\/\/'/" bin/omarchy-update-restart
        sed -i '/linux-cachyos/ ! s/pacman -Q linux/pacman -Q linux-cachyos/' bin/omarchy-update-restart
        echo "  - Patched omarchy-update-restart for CachyOS kernel."
    fi

    # Remove pacman.sh from preflight
    if grep -q 'run_logged.*preflight\/pacman\.sh' install/preflight/all.sh 2>/dev/null; then
        sed -i '/run_logged.*preflight\/pacman\.sh/d' install/preflight/all.sh
        echo "  - Removed pacman.sh from preflight/all.sh."
    fi

    # Remove limine-snapper.sh from login
    if grep -q 'run_logged.*login\/limine-snapper\.sh' install/login/all.sh 2>/dev/null; then
        sed -i '/run_logged.*login\/limine-snapper\.sh/d' install/login/all.sh
        echo "  - Removed limine-snapper.sh from login/all.sh."
    fi

    # Remove alt-bootloaders.sh from login
    if grep -q 'run_logged.*login\/alt-bootloaders\.sh' install/login/all.sh 2>/dev/null; then
        sed -i '/run_logged.*login\/alt-bootloaders\.sh/d' install/login/all.sh
        echo "  - Removed alt-bootloaders.sh from login/all.sh."
    fi

    # Remove pacman.sh from post-install
    if grep -q 'run_logged.*post-install\/pacman\.sh' install/post-install/all.sh 2>/dev/null; then
        sed -i '/run_logged.*post-install\/pacman\.sh/d' install/post-install/all.sh
        echo "  - Removed pacman.sh from post-install/all.sh."
    fi

    # Update mise activation for bash and fish
    if grep -q 'omarchy-cmd-present mise && eval "\$(mise activate bash)"' config/uwsm/env 2>/dev/null; then
        sed -i 's/omarchy-cmd-present mise && eval "\$(mise activate bash)"/if [ "\$SHELL" = "\/bin\/bash" ] \&\& command -v mise \&> \/dev\/null; then\n  eval "\$(mise activate bash)"\nelif [ "\$SHELL" = "\/bin\/fish" ] \&\& command -v mise \&> \/dev\/null; then\n  mise activate fish | source\nfi/' config/uwsm/env
        echo "  - Patched mise activation for bash/fish."
    fi

    checkpoint_set "patch_scripts"
else
    echo "[✓] Script patching already completed, skipping."
fi

# ─── 11. Copy to ~/.local/share/omcachy ──────────────────────────────────────
if ! checkpoint_done "copy_local"; then
    echo "Copying Omcachy to ~/.local/share/omcachy..."

    # Remove any stale previous copy (may have root-owned .git files from a failed run)
    if [ -d ~/.local/share/omcachy ]; then
        echo "  Removing previous partial copy..."
        sudo rm -rf ~/.local/share/omcachy
    fi

    mkdir -p ~/.local/share/omcachy

    # Copy everything except .git — it's not needed for installation
    rsync -a --exclude='.git' "${REPO_DIR}/" ~/.local/share/omcachy/

    checkpoint_set "copy_local"
else
    echo "[✓] Copy to ~/.local/share/omcachy already completed, skipping."
fi

cd ~/.local/share/omcachy

# ─── 12. Run Omcachy installer ───────────────────────────────────────────────
echo ""
echo "The following adjustments have been completed."
echo " 1. Renamed display/branding text from Omarchy to Omcachy."
echo " 2. Preserved all upstream package names, commands, and paths (omarchy-*)."
echo " 3. Replaced branding assets (logo.txt, logo.svg, icon.txt, icon.svg, icon.png)."
echo " 4. Added Omarchy repo to pacman.conf (if not already present)."
echo " 5. Removed tldr from packages to avoid conflict with tealdeer on CachyOS."
echo " 6. Disabled further Omarchy changes to pacman.conf, preserving CachyOS settings."
echo " 7. Removed limine-snapper.sh to avoid conflict with CachyOS boot loader."
echo " 8. Removed alt-bootloaders.sh to avoid conflict with CachyOS boot loader."
echo " 9. Removed /etc/sddm.conf to avoid conflict with Omcachy UWSM session autologin."
echo ""
echo "Press Enter to begin the installation of Omcachy..."
read -r

chmod +x install.sh
./install.sh

# ─── Done — clean up checkpoints ─────────────────────────────────────────────
echo ""
echo "Installation complete! Cleaning up checkpoints..."
rm -rf "$CHECKPOINT_DIR"
# Temp directory is cleaned up automatically by the EXIT trap
echo "Done."
