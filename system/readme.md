# System configuration, packages and upgrades

This project supplies a reusable desktop module for a locally maintained NixOS configuration. Project-relative commands use the repository root. Initial GH, VLC, and VSCodium files become user-owned preferences with application-specific update workflows. Capturing GUI changes in project sources is a separate authoring step.

## Integrate the desktop module

The public module repository omits a lockfile. The installer records resolved desktop and Nixpkgs revisions in each machine's `/etc/nixos/flake.lock`; its local `nixpkgs` follows the desktop input. The instructions below apply to another existing local flake with its own independent `nixpkgs` input.

Add this input alongside it:

```nix
    desktop.url = "github:SorinGFS/nixos";
    desktop.inputs.nixpkgs.follows = "nixpkgs";
```

Bind the local flake's inputs in its existing `outputs` function, retaining the rest of its definition:

```nix
    outputs = inputs@{ nixpkgs, ... }:
```

In the existing local `nixpkgs.lib.nixosSystem` definition, add this entry to its `modules` list:

```nix
    inputs.desktop.nixosModules.default
```

The local configuration retains its existing hostname, user accounts, hardware imports, bootloader, filesystems, and `system.stateVersion`. The shared module configures NetworkManager and libvirtd and disables sudo; local account definitions should grant the intended operators `wheel`, `networkmanager`, and `libvirtd` group membership as appropriate. Root authentication through `su` requires a locally managed root password. Select filesystem mount ownership in the local configuration.

## Unlock and mount data storage

Data protection requires a separate backup in addition to the data partition.

For a local configuration with the described data volume, these commands run in the installed NixOS session as an authorized operator. This example keeps the home directory on the Linux root filesystem and mounts the data volume at `/data`.

Identify the data partition with:

```bash
    lsblk -p
```

The prompt accepts the verified full path of that physical partition. The existing data volume retains its filesystem and contents.

```bash
    read -r -p 'BitLocker partition: ' data_partition
```

The prompt accepts the BitLocker password or recovery password; desktop authorization may also be requested.

```bash
    udisksctl unlock -b "$data_partition"
```

```bash
    udisksctl mount -b /dev/disk/by-label/NIXOS_DATA
```

Official reference: [udisksctl unlock and mount](https://storaged.org/doc/udisks2-api/latest/udisksctl.1.html).

The [installation procedure](../install.md) covers first installation and live-environment storage steps.

Mounted storage can support [project-relative commands](#before-running-commands).

## Before running commands

Commands run in the installed NixOS session as the administrator; administration uses root authentication through `su -c`. Project-relative tasks run from the repository root.

## Apply native configuration edits

After saving local configuration edits, run the following from the directory containing the local flake. The local flake provides a `nixosConfigurations` entry matching the current hostname:

```bash
    su -c 'nixos-rebuild switch --flake path:.'
```

A successful rebuild applies system configuration and unlocked GNOME and Firefox defaults in `settings/`. Continuation depends on the rebuild result. Existing user preferences take precedence. GH, VLC, and VSCodium defaults seed missing user files at user-manager startup or activation; existing files remain user-owned. A new login may be needed.

From the local flake directory, the following evaluation returns the full system derivation path for the same local attribute:

```bash
    nix eval --raw "path:.#nixosConfigurations.$(uname -n).config.system.build.toplevel.drvPath"
```

Evaluation checks the derivation; activation and application behavior require separate verification. Public source checks: [settings JSON validation](../settings/readme.md#validation) and [VSCodium validation](../settings/vscodium/readme.md#validation).

Official reference: [NixOS configuration](https://nixos.org/manual/nixos/stable/#sec-changing-config).

## Inspect boot storage

Where the local configuration uses separate `/boot` and `/boot/efi` filesystems, their current usage informs diagnosis of a full boot partition:

```bash
    df -h /boot /boot/efi
```

Bootloader and kernel payloads occupy boot storage; Nix store closures and retained rollback generations consume store space within the same installation. This inspection reports usage and leaves generations and store contents intact.

## Install or uninstall a native application

[NixOS package search](https://search.nixos.org/packages) identifies attributes for the existing native package list:

```bash
    codium ./system/desktop-features.nix
```

For example, `gnumake` is already in `environment.systemPackages = with pkgs; [ ... ]` and supplies `make`. Its presence in that list determines installation; changes reach the local system when its desktop input includes them and the operator [applies the configuration](#apply-native-configuration-edits).

Module-managed features use their existing module options. Native application installation is owned exclusively by the declarative system configuration.

Official references: [package management](https://nixos.org/manual/nixos/stable/#sec-package-management), [configuration and module syntax](https://nixos.org/manual/nixos/stable/#sec-configuration-syntax).

## Update the desktop input and apply it

From any directory, run this standalone command. Enter the root password when prompted; it updates the GitHub desktop input and its dependencies in the machine-local `/etc/nixos/flake.lock`, then builds and activates the machine configuration. Local hardware, accounts, storage, and boot settings remain defined by that machine's configuration.

```bash
    cd /etc/nixos && su -c 'nix flake update && nixos-rebuild switch --flake path:.'
```

Shared-source changes become available through the GitHub `desktop` input after publication.

## One-off tools from GitHub flakes

In a normal user terminal, run an exported program once:

```bash
    nix run github:OWNER/REPO#APP
```

Replace `OWNER/REPO` with the GitHub repository and `APP` with its exported program name, as documented by that project. Not every flake exports a program. The program's actions can make persistent changes of their own.

To use an exported package in a temporary shell environment:

```bash
    nix shell github:OWNER/REPO#PACKAGE
```

Replace `PACKAGE` with an exported package name documented by that project. Not every flake exports a package. Type `exit` to leave the shell environment.

Neither command adds an input to `/etc/nixos/flake.nix` or updates its lockfile. Downloaded and built store objects remain cached after either command.

## Bash and console access

The system-managed interactive Bash configuration in [system/core.nix](core.nix) applies to new interactive Bash sessions, including Kitty and the VSCodium terminal, after [applying the project](#apply-native-configuration-edits).

Verification in a new terminal uses `type fnm`, `type z`, `node --version`, and the Git branch prompt. Moving between projects with `.node-version` or `.nvmrc` files exercises version switching; `node --version` confirms the result. Switching requires installed versions. [Setup rationale](../readme.md#setup-rationale) describes shell and toolchain ownership.

Console access is independent of GNOME; actual login and root authentication require a local test:

1. With work saved, Ctrl+Alt+F3 switches to an available console.
2. Normal-user login followed by `su` and root-password authentication tests console administration.
3. Exiting the root shell and console session allows a return to the virtual terminal hosting GNOME.

Console recovery depends on a successful local login and authentication test; failures require investigation from GNOME.

The separate graphical VSCodium process and its Node environment are covered in [Desktop launch environment](../settings/vscodium/readme.md#desktop-launch-environment).

## Kitty terminal preferences

The project-relative source path below assumes [Before running commands](#before-running-commands).

Kitty replaces GNOME Terminal in the native configuration. Its system defaults live here:

```bash
    codium ./system/desktop-features.nix
```

The `environment.etc."xdg/kitty/kitty.conf".text` block sets MesloLGM Nerd Font Mono at size 11 and a beam cursor, copies terminal selections to the clipboard, and pastes the clipboard on right-click when Kitty controls mouse input. Blinking follows the system setting; terminal applications can override the cursor shape. Closing a window or tab can immediately terminate running commands. In mouse-aware applications, Kitty's Shift+left-drag provides terminal selection; application selection behavior can differ. A mouse-grabbing application receives right-click directly and controls its behavior. `wl-clipboard` is installed for Pi's Wayland clipboard integration.

Saved changes take effect in a new Kitty window after [project activation](#apply-native-configuration-edits). Kitty uses the first configuration file it finds: a user config or `KITTY_CONFIG_DIRECTORY` can take precedence over the system file. The configured XDG terminal launcher prefers Kitty for its callers; individual applications can choose their own terminal action.

Official documentation: [Kitty configuration](https://sw.kovidgoyal.net/kitty/conf/) and [configuration lookup](https://sw.kovidgoyal.net/kitty/invocation/).

Source: [system/desktop-features.nix](desktop-features.nix).

## tmux sessions

After [project activation](#apply-native-configuration-edits), the following command starts a named terminal session:

```bash
    tmux new -s work
```

Ctrl+b, then d detaches while keeping the session running; `tmux attach -t work` reconnects. Inside tmux, Ctrl+b followed by `%` splits left/right, `"` splits top/bottom, and an arrow key selects a neighboring pane. tmux is an optional session layer alongside Kitty, GNOME, and Bash.

## Planned media and document tools

FFmpeg, ImageMagick, and Pandoc remain planned additions. Pandoc is planned as a straightforward package; the planned FFmpeg/ImageMagick builds include custom-built libraries. Their source builds are intended to remain outside the installed desktop; artifact integration remains an open design decision. The existing rcon workflow produces Debian packages; NixOS integration remains future work.

## Launch the existing KeePass application with GTK 2 libraries

The native configuration provides `keepass-local` for the existing `$HOME/.logins/KeePass.exe`. The launcher becomes available after [project activation](#apply-native-configuration-edits) and runs as the normal user:

```bash
    keepass-local
```

The launcher supplies Nix-managed GTK 2 libraries only to that Mono process, preserving any existing `LD_LIBRARY_PATH`, and forwards command-line arguments unchanged. The KeePass executable and database remain in their existing locations; browser integration remains separately managed. Direct `mono KeePass.exe` launches use the caller's environment.

This targets the GTK color-scheme warning; Auto-Type compatibility is a separate concern. Runtime verification remains pending and requires checking the warning and appearance after launch.

Source: [system/desktop-features.nix](desktop-features.nix).
