# NixOS setup

NixOS 26.05 with GNOME personal setup.
The machine-local flake supplies the host, hardware and lock after [installation](./install.md).

## Flake integration

### Fresh installation

The installer has already combined the local machine configuration with the shared desktop module and built the initial boot generation. No separate import is needed. The generated files are under `/mnt/etc/nixos` while the target is mounted in the live session and under `/etc/nixos` after boot:

| File | Role |
| --- | --- |
| `flake.nix` | Declares the shared input and combines its `nixosModules.default` module with `configuration.nix` in a host output named after the chosen hostname. The host follows the shared flake's Nixpkgs input. |
| `flake.lock` | Records the exact revisions of the shared project, Nixpkgs, and other inputs. |
| `configuration.nix` | Defines machine-local settings such as the hostname, accounts, bootloader, and regional preferences. |
| `hardware-configuration.nix` | Contains the generated hardware and filesystem settings imported by `configuration.nix`. |

### Existing host flake

An existing host flake can keep its own Nixpkgs input and have the shared desktop follow it. This example shows the full connection; `my-host` stands for the existing host output name. The existing machine configuration, hardware imports, and `system.stateVersion` remain in place.

```nix
{
    inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    inputs.desktop.url = "github:SorinGFS/nixos";
    inputs.desktop.inputs.nixpkgs.follows = "nixpkgs";

    outputs = inputs@{ nixpkgs, ... }: {
        nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
            modules = [
                ./configuration.nix
                inputs.desktop.nixosModules.default
            ];
        };
    };
}
```

In an existing flake, the new input and module entry are added to the existing definitions rather than replacing the entire file. Its matching lock is refreshed as described under [Updates](#updates).

## Configuration

### Editing local settings

A configuration backup includes the local Nix files and their matching `flake.lock`. Timezone, locale, X keyboard layout, console keymap, and unattended-upgrade policy belong in `configuration.nix`. Regional settings use NixOS defaults until configured locally.

In the live session, from the root shell left open after installation:

```bash
nano /mnt/etc/nixos/configuration.nix
```

On the booted system, with root authentication:

```bash
su -c 'nano /etc/nixos/configuration.nix'
```

A timezone setting belongs inside the existing outer `{ ... }` block, before its final `}`. This example uses `Europe/Bucharest`; an existing `time.timeZone` setting is replaced rather than duplicated.

```nix
time.timeZone = "Europe/Bucharest";
```

In Nano, Ctrl+O saves the file, Enter confirms its name, and Ctrl+X exits. Saving changes the source files, not the running system or the next boot generation.

### Before first boot

With the target filesystems still mounted as the installer left them, the initial generation is ready to boot unless local edits need to be included. For those edits, the following commands run in the live root shell. The script's `host` variable does not survive its exit, so the first command loads the exact output name from the installer-generated `flake.nix` into the shell:

```bash
host=$(awk -F '"' '/^[[:space:]]*nixosConfigurations\."/ { print $2 }' /mnt/etc/nixos/flake.nix)
[[ $host =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]] && env -u TMPDIR nixos-install --root /mnt --flake "path:/mnt/etc/nixos#$host" --no-root-passwd --no-channel-copy
```

Native `nixos-install` builds the revised configuration and registers it for the next boot. It does not reformat partitions or switch the live system. Unsetting `TMPDIR` lets it put its temporary build files on the mounted target by default.

- `--no-root-passwd` skips the root-password prompt; the password was already set during installation.
- `--no-channel-copy` skips copying the live USB's legacy Nix channel to the target. The machine-local flake and its lock select the inputs instead.

The hostname check prevents installation if the generated file does not yield a single valid name. After a successful build and bootloader update, a manual reboot starts the revised generation. If no changes were made, the initial generation is already ready to boot.

### After first boot

A normal-user build checks the saved configuration without activating it or creating a `result` link:

```bash
cd /etc/nixos && nixos-rebuild build --flake path:. --no-link
```

After a successful build, switching makes the generation current and sets it as the boot default. It requires root authentication and may restart services. With no explicit output name, `nixos-rebuild` uses the running system's hostname. For an existing flake with a differently named output, both commands take `path:.#<output-name>` instead of `path:.`.

```bash
cd /etc/nixos && su -c 'nixos-rebuild switch --flake path:.'
```

## Updates

Local settings can be built and applied without refreshing the inputs. Published changes to the shared GitHub flake are not selected until the local lock changes. The following command refreshes all inputs, including Firefox Nightly, in the booted system's `flake.lock`:

```bash
cd /etc/nixos && su -c 'nix flake update --flake path:.'
```

Refreshing the lock does not build or activate a new generation. The build and switch steps under [After first boot](#after-first-boot) apply the updated inputs.

## References

- [Modules](modules/readme.md)
- [Tutorial](tutorial/readme.md)
