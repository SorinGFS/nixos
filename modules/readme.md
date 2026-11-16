# Desktop modules

This collection exports reusable NixOS modules; the machine-local flake supplies the host, hardware and lock. The [installation guide](../install.md) covers initial setup.

## Integration and ownership

The root flake delegates its output function to [exports.nix](exports.nix). The `desktop` and `default` wrappers pass the root inputs as `_module.args.desktopInputs`; [Firefox](applications/firefox/readme.md) consumes its Nightly input. The complete `nixosModules.default` imports the desktop, [power](power/readme.md), [libvirt](virtualisation/libvirt/readme.md), and [KeePass](applications/keepass/readme.md) policies. The separately exported `desktop`, `power`, `virtualisation`, and `keepass` modules permit narrower composition. Desktop alone disables sudo, but omits power policy, libvirt, and KeePass including its shortcut.

The local host owns accounts, hardware, disks, bootloader, timezone, locale, X keyboard layout, console keymap, unattended upgrades, and `system.stateVersion`. The complete preset enables NetworkManager and libvirt, disables sudo and sleep, and defaults the CPU governor to performance. Configure appropriate `wheel`, `networkmanager`, and `libvirtd` memberships locally. Establish a root password and working `su` access before activation. `system.stateVersion` controls persistent-state compatibility defaults; it is not a package pin.

The public source omits a lockfile; the consumer's local lock selects revisions. The installer makes local `nixpkgs` follow `desktop/nixpkgs`. An independent existing consumer should instead make `desktop/nixpkgs` follow its own `nixpkgs`, avoiding a follows cycle:

```nix
    desktop.url = "github:SorinGFS/nixos";
    desktop.inputs.nixpkgs.follows = "nixpkgs";
```

Bind `inputs@{ nixpkgs, ... }` in the consumer's outputs and add `inputs.desktop.nixosModules.default` to its existing `nixosSystem.modules`. Substitute `inputs.desktop.nixosModules.desktop` for the narrower composition; add individual exports as needed. See [NixOS module writing](https://nixos.org/manual/nixos/stable/#sec-writing-modules) and the [composition tutorial](../tutorial/nix.md#source-imports-and-module-composition).

Commands run as the normal user in the installed session; commands using `su -c` request root authentication. Project-relative source paths and commands assume the repository root.

## Apply local configuration and update the whole system

The host may set `system.autoUpgrade.enable = false`; its NixOS default is also false. The public module does not choose this policy. The local lock determines the selected desktop, Nixpkgs and Firefox Nightly revisions. Publishing a shared-source change makes it available to a GitHub input, but the consumer must refresh that input before the published change applies. A rebuild with the previous lock does not incorporate it.

Before updating, save work and back up the coherent local configuration source **and matching lock**, mutable application data and profiles. Confirm a known-good boot generation and recovery path. Flake sources enter the store and published sources are public; keep credentials out of them. `su` commands request root authentication.

1. Refresh all inputs, including the nested Nightly input. This changes the local lock and may download sources; it does not activate a generation.

    ```bash
    cd /etc/nixos && su -c 'nix flake update'
    ```

2. Build as the normal user. This can download or build dependencies but does not activate them; `--no-link` avoids a result link. A successful build does not establish runtime correctness. A failed build leaves the refreshed lock in place.

    ```bash
    cd /etc/nixos && nixos-rebuild build --flake path:. --no-link
    ```

3. Review source and lock changes, then activate only when ready for runtime changes. Switching may restart services, interrupt work, or partially fail; inspect its result.

    ```bash
    cd /etc/nixos && su -c 'nixos-rebuild switch --flake path:.'
    ```

4. Fully restart Firefox for the new browser, and reboot when changed kernel, drivers, initrd, or other boot-time components require it. Browser startup can migrate profiles; rolling back a generation does not restore mutable data. To abandon an update, restore the coherent source and matching lock backup before rebuilding. User-managed software has separate update procedures.

A local-only source edit can be applied with the build and switch stages without refreshing inputs. To evaluate the system derivation path rather than request its build or activation, a local flake with a `nixosConfigurations` attribute matching the current hostname can use this example:

```bash
cd /etc/nixos && nix eval --raw "path:.#nixosConfigurations.$(uname -n).config.system.build.toplevel.drvPath"
```

This returns a recipe path, not a build, activation or runtime result. Supported releases and available upstream fixes determine security maintenance; changing release branches is a separate decision. See [NixOS upgrades](https://nixos.org/manual/nixos/stable/#sec-upgrading), [configuration changes](https://nixos.org/manual/nixos/stable/#sec-changing-config), and the [update model](../tutorial/nix.md#11-manual-updates-across-four-kinds-of-state).

## Storage and boot inspection

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

See [udisksctl](https://storaged.org/doc/udisks2-api/latest/udisksctl.1.html) and [garbage collection and rollback retention](nix/readme.md#garbage-collection-and-rollback-retention).

## Guides

- [Applications](applications/readme.md)
- [Desktop](desktop/readme.md)
- [Fonts](fonts/readme.md)
- [Nix settings and retention](nix/readme.md)
- [Power](power/readme.md)
- [Security](security/readme.md)
- [Services](services/readme.md)
- [Shell](shell/readme.md)
- [Virtualisation](virtualisation/readme.md)
