# Plan: Configure GRUB dual-boot on Gaia

## Context
Gaia (Ubuntu 24.04) has Windows installed on a separate NTFS partition but GRUB doesn't show it because Ubuntu 24.04 disables os-prober by default and the GRUB menu is hidden with 0s timeout.

## Changes to `/etc/default/grub` on gaia (via SSH)

1. **Uncomment** `GRUB_DISABLE_OS_PROBER=false` — enables Windows detection
2. **Set** `GRUB_TIMEOUT=5` — 5 seconds to pick an OS
3. **Set** `GRUB_TIMEOUT_STYLE=menu` — always show the menu

## Commands (require sudo)

```bash
# Edit GRUB config
sudo sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
sudo sed -i 's/^GRUB_TIMEOUT=0/GRUB_TIMEOUT=5/' /etc/default/grub
sudo sed -i 's/^GRUB_TIMEOUT_STYLE=hidden/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub

# Regenerate GRUB config
sudo update-grub
```

## Verification
- `update-grub` output should show "Found Windows Boot Manager on /dev/nvme0n1p..."
- `grep -c windows /boot/grub/grub.cfg` should return > 0
