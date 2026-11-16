# NixOS terminal cookbook

NixOS 26.05 with GNOME personal setup.
The machine-local flake supplies the host, hardware and lock after [installation](./install.md).

## Apply local configuration and update the whole system

Use the machine-local consumer in `/etc/nixos`, not the public source checkout. Run commands as the normal user in the installed session; `su -c` requests root authentication. The complete preset disables sudo: establish a root password and working `su` access before activation.

Before applying or updating, save work and back up the coherent local configuration source **and matching lock**, mutable application data and profiles. Confirm a known-good boot generation and recovery path. Flake sources enter the store and published sources are public; keep credentials out of them. Switching may restart services, interrupt work, or partially fail; inspect its result.

### Apply local configuration

1. Build as the normal user. This can download or build dependencies but does not activate them; `--no-link` avoids a result link. A successful build does not establish runtime correctness.

    ```bash
    cd /etc/nixos && nixos-rebuild build --flake path:. --no-link
    ```

2. Review source and lock changes, then activate only when ready for runtime changes.

    ```bash
    cd /etc/nixos && su -c 'nixos-rebuild switch --flake path:.'
    ```

Fully restart Firefox for a new browser, and reboot when changed kernel, drivers, initrd, or other boot-time components require it. Browser startup can migrate profiles; rolling back a generation does not restore mutable data. To abandon an update, restore the coherent source and matching lock backup before rebuilding. User-managed software has separate update procedures.

### Update inputs

Refresh all inputs, including the nested Firefox Nightly input. This changes the local lock and may download sources; it does not activate a generation.

```bash
cd /etc/nixos && su -c 'nix flake update'
```

Then repeat the build and switch stages above. A failed build leaves the refreshed lock in place. Publishing a shared-source change makes it available to a GitHub input, but the consumer must refresh that input before the published change applies; rebuilding with the previous lock does not incorporate it.

<details>
<summary>Integration, update policy and inspection</summary>

The root [flake.nix](flake.nix) delegates its output function to [modules/exports.nix](modules/exports.nix); the [module guide](modules/readme.md) describes the exported compositions.

The local host owns accounts, hardware, disks, bootloader, timezone, locale, X keyboard layout, console keymap, unattended upgrades, and `system.stateVersion`. Configure appropriate `wheel`, `networkmanager`, and `libvirtd` memberships locally. `system.stateVersion` controls persistent-state compatibility defaults; it is not a package pin. The host may set `system.autoUpgrade.enable = false`; its NixOS default is also false. The public module does not choose this policy. The local lock determines the selected desktop, Nixpkgs and Firefox Nightly revisions.

The public source omits a lockfile; the consumer's local lock selects revisions. The installer makes local `nixpkgs` follow `desktop/nixpkgs`. An independent existing consumer should instead make `desktop/nixpkgs` follow its own `nixpkgs`, avoiding a follows cycle:

```nix
    desktop.url = "github:SorinGFS/nixos";
    desktop.inputs.nixpkgs.follows = "nixpkgs";
```

Bind `inputs@{ nixpkgs, ... }` in the consumer's outputs and add `inputs.desktop.nixosModules.default` to its existing `nixosSystem.modules`. Substitute `inputs.desktop.nixosModules.desktop` for the narrower composition; add individual exports as needed. See [NixOS module writing](https://nixos.org/manual/nixos/stable/#sec-writing-modules) and the [composition tutorial](tutorial/nix.md#source-imports-and-module-composition).

Project-relative source paths and commands assume the repository root.

To evaluate the system derivation path rather than request its build or activation, a local flake with a `nixosConfigurations` attribute matching the current hostname can use this example:

```bash
cd /etc/nixos && nix eval --raw "path:.#nixosConfigurations.$(uname -n).config.system.build.toplevel.drvPath"
```

This returns a recipe path, not a build, activation or runtime result. Supported releases and available upstream fixes determine security maintenance; changing release branches is a separate decision. See [NixOS upgrades](https://nixos.org/manual/nixos/stable/#sec-upgrading), [configuration changes](https://nixos.org/manual/nixos/stable/#sec-changing-config), and the [update model](tutorial/nix.md#11-manual-updates-across-four-kinds-of-state).

</details>

<details>
<summary>Storage and boot inspection</summary>

Back up data separately. In Files an encrypted data volume may be unlocked interactively. Alternatively inspect devices using `lsblk -fp`, verify the BitLocker partition, and unlock it as the normal user:

```bash
udisksctl unlock -b /dev/VERIFIED_PARTITION
```

After inspecting again, mount the verified unlocked filesystem without specifying a location:

```bash
udisksctl mount -b /dev/VERIFIED_UNLOCKED_DEVICE
```

Udisks reports the mount point, normally under `/run/media/$USER/LABEL`. For an optional explicit NTFS mount at `/data`, first ensure the verified filesystem is not mounted and that the mount point is appropriate and empty. Obtain the intended numeric UID and GID with `id -u` and `id -g`; replace UID, GID and LABEL with verified values and escape shell-special characters:

```bash
su -c 'mkdir -p /data && mount -t ntfs3 -o uid=UID,gid=GID,dmask=0077,fmask=0077,nosuid,nodev -L "LABEL" /data'
```

This does not format the filesystem or require unmounting an in-use data volume. The host owns mount policy. Where separate boot filesystems exist, inspect usage without changing them:

```bash
df -h /boot /boot/efi
```

Bootloader and kernel payloads occupy boot storage; store closures and retained generations consume store space and need not be on the same filesystem as `/boot`. This inspection changes neither.

See [udisksctl](https://storaged.org/doc/udisks2-api/latest/udisksctl.1.html) and [garbage collection and rollback retention](modules/nix/readme.md#garbage-collection-and-rollback-retention).

</details>

## References

- [Modules](modules/readme.md)
- [Tutorial](tutorial/readme.md)
