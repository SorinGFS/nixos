# Fresh installation

Disk preparation from the NixOS live USB shell is covered in the official [partitioning and formatting instructions](https://nixos.org/manual/nixos/stable/#sec-installation-manual-partitioning). When the live USB has no graphical desktop, `cfdisk` provides an interactive terminal interface for partitioning.

## Requirements

Run the installer as root from a NixOS live session. `nix-shell` provides Python 3, jq, and curl; network access fetches tools and scripts. The installer uses existing partitions, the native Nix CLI, and available native NixOS installation tools. It pins the desktop inputs before graphics selection; cancellation removes the temporary staging directory but may leave Nix source cache entries.

- At least **8 GB of Linux-reported total RAM** and a root partition of at least **20 GB**.
- Select an existing root partition. For UEFI, select an existing FAT EFI System Partition. GRUB can use a separate Linux `/boot` partition; systemd-boot uses the ESP for `/boot`. For BIOS, select a DOS/MBR disk or a GPT disk with a raw BIOS Boot reservation, and optionally a separate Linux `/boot` partition.
- Choose the default kernel/Mesa graphics option or query a compatible NVIDIA driver. The NVIDIA query uses the companion [`install-nvidia.py`](install-nvidia.py) and requires Python 3, Nix, curl, and network access. The query retrieves upstream compatibility data and can populate the live Nix source/cache.

## Install

From the NixOS live USB console, enter a root login shell providing git, Python 3, jq, and curl, then run install command:

```bash
sudo -i
nix-shell -p git python3 jq curl
cd /tmp && git clone --depth 1 https://github.com/SorinGFS/nixos && bash nixos/install.sh
```

Choose the existing partitions and review the preview. Answer `yes` to begin installation, or `no` to cancel.

**Formatting erases data on the selected root and separate `/boot` partitions.** Back up important data before continuing. A native command failure stops the workflow, and completed operations remain in effect.

## Process Model

1. Preflight checks require root privileges, the native installation commands, and at least 8 GB of Linux-reported total RAM.
2. The native hardware preview and block-device inventory appear first, followed by the detected firmware mode or the selected override.
3. Firmware mode determines the bootloader and storage options. The root partition must be at least 20 GB. UEFI requires an existing EFI System Partition; BIOS uses GRUB and requires a disk with a supported partition layout. GRUB supports an optional separate Linux `/boot` partition.
4. The shared flake inputs are pinned before graphics selection. The pinned Nixpkgs revision determines the target release. The graphics menu offers the kernel/Mesa defaults or an NVIDIA compatibility query against the pinned public module defaults and kernel packages.
5. The administrator and hostname prompts precede a compact preview of the installation choices.
6. The final confirmation gates destructive operations. A `yes` response starts installation; `no` or end-of-input cancels it.
7. The selected root and optional separate `/boot` partitions are formatted as ext4 and mounted at `/mnt` and `/mnt/boot`, respectively. The EFI System Partition is mounted without reformatting at `/mnt/boot` for systemd-boot or `/mnt/boot/efi` for GRUB.
8. `nixos-generate-config --root /mnt` generates `hardware-configuration.nix`, which is retained. The installer writes `/mnt/etc/nixos/configuration.nix` with the selected settings and the initial state version from the pinned target release. It also writes the machine-local `flake.nix` importing the full public desktop module and copies the staged `flake.lock`. These files govern subsequent updates.
9. `nixos-install` uses the machine-local flake and selected hostname with `TMPDIR` unset. It prompts for the root password and installs the bootloader, writing boot files and potentially updating firmware entries.
10. Native `passwd` prompts for the administrator password. After successful completion, the target filesystems remain mounted at `/mnt`; there is no automatic reboot.

The full public desktop is included at first boot. Timezone, locale, X keyboard layout, console keymap, and unattended-upgrade policy belong to the machine-local configuration. CLI installations use NixOS upstream regional defaults until those choices are configured locally.
