# Fresh installation

Disk preparation from the NixOS live USB shell is covered in the official [partitioning and formatting instructions](https://nixos.org/manual/nixos/stable/#sec-installation-manual-partitioning).

## Requirements

Run the installer as root from a NixOS live session. `nix-shell` provides Python 3, jq, and curl; network access fetches tools and scripts. The installer uses existing partitions, the native Nix CLI, and available native NixOS installation tools. It pins the desktop inputs before graphics selection; cancellation removes the temporary staging directory but may leave Nix source cache entries.

- At least **8 GB of Linux-reported total RAM** and a root partition of at least **20 GB**.
- Select an existing root partition. For UEFI, select an existing FAT EFI System Partition. GRUB can use a separate Linux `/boot` partition; systemd-boot uses the ESP for `/boot`. For BIOS, select a DOS/MBR disk or a GPT disk with a raw BIOS Boot reservation, and optionally a separate Linux `/boot` partition.
- Choose the default kernel/Mesa graphics option or query a compatible NVIDIA driver. The NVIDIA query uses the companion [`install-nvidia.py`](install-nvidia.py) and requires Python 3, Nix, curl, and network access. The query retrieves upstream compatibility data and can populate the live Nix source/cache.

## Run

From the NixOS live USB console, run this single command to enter a root login shell and provide Python 3, jq, and curl:

```bash
sudo -i bash -c 'cd /tmp && nix-shell -p python3 jq curl --run "curl -fLO https://raw.githubusercontent.com/SorinGFS/nixos/main/install.sh && curl -fLO https://raw.githubusercontent.com/SorinGFS/nixos/main/install-nvidia.py && bash ./install.sh"'
```

Choose the existing partitions and review the preview. Answer `yes` to begin installation, or `no` to cancel.

**Formatting erases data on the selected root and separate `/boot` partitions.** Back up important data before continuing. A native command failure stops the workflow, and completed operations remain in effect.

## Process Model

1. Verify that the installer runs as root, required native commands are available, and Linux-reported total RAM is at least 8 GB.
2. Display the native hardware preview and block-device inventory, then report detected firmware or the selected firmware override.
3. Select the bootloader and existing partitions according to the firmware mode. The root partition must be at least 20 GB; select an EFI System Partition for UEFI and the supported BIOS disk layout for BIOS. GRUB can use an optional separate Linux `/boot` partition.
4. Pin the shared flake inputs and read the target release from pinned Nixpkgs. Choose the default kernel/Mesa graphics option or query a compatible NVIDIA driver against the pinned public module defaults and kernel packages.
5. Collect the administrator username and hostname, then review the compact installation preview.
6. Answer the final `yes`/`no` prompt; `yes` proceeds with installation.
7. Format the selected root and optional separate `/boot` partitions as ext4. Mount the root at `/mnt`, the optional `/boot` at `/mnt/boot`, and the EFI System Partition at `/mnt/boot` for systemd-boot or `/mnt/boot/efi` for GRUB. The ESP filesystem is preserved.
8. Run native `nixos-generate-config --root /mnt` and write `/mnt/etc/nixos/configuration.nix` with the selected settings and initial state version from the pinned target release. Retain the generated `hardware-configuration.nix`, write a machine-local `flake.nix` importing the full public desktop module, and copy the staged `flake.lock`. These files are the local source of truth for subsequent updates.
9. Run `nixos-install` against the local flake and selected hostname with `TMPDIR` unset. Native installation handles bootloader setup and prompts for the root password; bootloader installation writes its boot files and may update firmware entries.
10. Set the administrator password at the native `passwd` prompt. After successful completion, leave target filesystems mounted at `/mnt`; reboot manually when ready.

The full public desktop is included at first boot. Timezone, locale, X keyboard layout, console keymap, and unattended-upgrade policy belong to the machine-local configuration. CLI installations use NixOS upstream regional defaults until those choices are configured locally. For later input updates and rebuilds, use the [local configuration workflow](modules/readme.md#apply-local-configuration-and-update-the-whole-system). Configuration is documented in [readme.md](readme.md).
