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

## Re-running the installer

The script is **idempotent** and uses a checkpoint system. If it fails or is interrupted:

Checkpoints are stored in `~/.cache/omcachy-install/` and are cleaned up automatically after a successful installation.