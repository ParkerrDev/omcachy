# Omcachy - Omarchy for CachyOS

![Logo](assets/color-logo.svg)

Brings the best of both worlds in terms of desktop envioronment and optimized speed.

## Prerequisites

- A fresh or existing **CachyOS** installation with No Desktop
- An active internet connection

## Installation

```bash
git clone https://github.com/ParkerrDev/omcachy.git /tmp/omcachy
cd /tmp/omcachy
chmod +x install.sh
./install.sh
```

### 4. Follow the prompts

The script will walk you through the following:

1. **Username & email** — Used for your Omcachy configuration.
2. **Summary of changes** — Review the CachyOS-specific adjustments before proceeding.
3. **Press Enter** — To begin the Omarchy installer with all patches applied.

## What the installer does

| Step | Description |
|------|-------------|
| Clone Omarchy | Clones the upstream Omarchy repo into a temporary directory |
| Rename to Omcachy | Renames all references from `omarchy` → `omcachy` (preserving upstream URLs) |
| Replace branding | Swaps logo and icon assets with your custom versions from `assets/` |
| Signing key | Imports and trusts the Omarchy package signing key |
| Pacman repo | Adds the Omarchy package repository to `/etc/pacman.conf` |
| Remove SDDM config | Removes `/etc/sddm.conf` to avoid conflicts with UWSM autologin |
| Patch scripts | Removes conflicting CachyOS scripts (pacman, limine-snapper, alt-bootloaders) |
| Install | Copies everything to `~/.local/share/omcachy` and runs the Omarchy installer |

## Re-running the installer

The script is **idempotent** and uses a checkpoint system. If it fails or is interrupted:

```bash
./install-omarchy-cachyos.sh
```

Simply run it again — it will **skip completed steps** and resume from where it left off. It will not:

- Re-clone the repo if already cloned
- Re-prompt for your username/email
- Append duplicate entries to `pacman.conf`
- Re-import already trusted signing keys
- Re-apply patches that have already been applied

Checkpoints are stored in `~/.cache/omcachy-install/` and are cleaned up automatically after a successful installation.

## Resetting the installer

If you want to start completely fresh:

```bash
rm -rf ~/.cache/omcachy-install
rm -rf ~/.local/share/omcachy
```

Then run the installer again.

## Troubleshooting

### No display manager after install

If you installed CachyOS **without a desktop environment**, you may not have a display manager. After the installer completes, run:

```bash
~/.local/share/omcachy/install/login/plymouth.sh
```

This will configure your boot to start Omcachy's Hyprland desktop automatically.

### paru build fails

Ensure you have the base development tools:

```bash
sudo pacman -S --needed git base-devel
```

### Signing key import fails

If the keyserver is unreachable, try again later or use a different keyserver:

```bash
sudo pacman-key --keyserver hkps://keys.openpgp.org --recv-keys F0134EE680CAC571
sudo pacman-key --lsign-key F0134EE680CAC571
```
