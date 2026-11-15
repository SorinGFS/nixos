# System configuration, packages and upgrades

This project supplies a reusable desktop module for a locally maintained NixOS configuration. Project-relative commands use the repository root. Initial GH, VLC, and VSCodium files become user-owned preferences with application-specific update workflows. Capturing GUI changes in project sources is a separate authoring step.

## Installation

The [installation procedure](../install.md) covers initial setup and integrates the desktop into a machine-local NixOS flake. Existing installations can use [desktop module integration](#integrate-the-desktop-module).

## Composition and ownership

[flake.nix](../flake.nix) declares external inputs and delegates its output function to [configuration.nix](configuration.nix), which exports reusable modules rather than an installed host. [core.nix](core.nix) owns GNOME, networking, and Bash initialization; [desktop-features.nix](desktop-features.nix) owns shared desktop services and packages. The local host owns timezone, locale, X keyboard layout, console keymap, unattended-upgrade policy, identity, accounts, boot, storage, hardware, and `system.stateVersion`. Changes reach the installed system through that local composition.

The [Firefox guide](../settings/firefox/readme.md#composition-and-revision-ownership) traces the exported module graph and external-input argument contract. Generic explanations cover [module imports](../tutorial/nix.md#source-imports-and-module-composition), [option priorities](../tutorial/readme.md#merging-definitions-by-type-and-priority), and [input sharing limits](../tutorial/nix.md#input-sharing-and-its-limits).

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

The local configuration retains its existing hostname, user accounts, hardware imports, bootloader, filesystems, and `system.stateVersion`. The complete preset configures NetworkManager and libvirtd, disables sudo and sleep, defaults to the performance CPU governor, and supplies the external KeePass launcher and shortcut. Local account definitions grant the intended operators `wheel`, `networkmanager`, and `libvirtd` group membership as appropriate. Root authentication through `su` requires a locally managed root password and working root access before activating this preset. Filesystem mount ownership remains local.

### Selecting policies

The complete preset remains `inputs.desktop.nixosModules.default`. A narrower composition uses `inputs.desktop.nixosModules.desktop` instead, retaining existing machine modules. It includes GNOME, Firefox, shared packages and unlocked preference defaults. Additional entries in the same `modules` list select policies independently:

| Additional module | Policy |
| --- | --- |
| `inputs.desktop.nixosModules.root-administration` | Root-authenticated administration through `su`, with sudo disabled. |
| `inputs.desktop.nixosModules.power` | Sleep disabled, power-profiles-daemon disabled, and a performance governor default. |
| `inputs.desktop.nixosModules.virtualisation` | Libvirt and virt-manager enabled, with the libvirt SSH proxy disabled. |
| `inputs.desktop.nixosModules.keepass` | External KeePass launcher and its unlocked GNOME shortcut. |

The KeePass policy expects `$HOME/.logins/KeePass.exe`; its launcher limits GTK and PATH changes to that application. The desktop-only composition leaves administration and power management to the local configuration and upstream defaults, and omits the VM service and KeePass launcher/shortcut.

The host configuration owns timezone, locale, X keyboard layout, and console keymap choices; machine-local definitions can also override the CPU governor default when the power policy is selected. The Firefox package is a native default: a local module with `pkgs` can set `programs.firefox.package = pkgs.firefox;` to select Nixpkgs Firefox without the Nightly X11 wrapper. Firefox preference defaults remain enabled.

The generic [package customization explanation](../tutorial/readme.md#package-overrides-and-package-set-overlays) distinguishes changing a package recipe from replacing a module option's default.

## Unlock and mount data storage

Data protection requires a separate backup in addition to the data partition.

A data disk can appear in GNOME Files without an `/etc/fstab` entry. After reboot an encrypted volume may appear locked; clicking it in Files can prompt for unlocking or open it. Alternatively, identify the physical partition with `lsblk -fp` and unlock the verified BitLocker partition in a normal user terminal:

```bash
    read -r -p 'BitLocker partition path: ' data_partition
    udisksctl unlock -b "$data_partition"
```

Enter the BitLocker password or recovery password when prompted; desktop authorization may also be requested. Inspect `lsblk -fp` again to identify the unlocked filesystem and its label. To let udisks choose the mount location, enter the verified unlocked filesystem device path:

```bash
    read -r -p 'Unlocked filesystem device path: ' data_device
    udisksctl mount -b "$data_device"
```

The command reports its mount point, normally under `/run/media/$USER/LABEL`, not `/data`.

To mount an unlocked **NTFS** filesystem explicitly at `/data` instead, unlock it without mounting it first. Ensure it is not already mounted and that `/data` is an appropriate empty mount point. In the normal user terminal, record the numerical UID and primary GID with `id -u` and `id -g`. Identify the unlocked filesystem's label with `lsblk -fp`, then replace `UID`, `GID`, and the quoted `LABEL` below with those verified values, escaping shell-special characters in the label. This example gives the selected user access with restrictive masks and does not format the filesystem or change its stored ownership:

```bash
    su -c 'mkdir -p /data && mount -t ntfs3 -o uid=UID,gid=GID,dmask=0077,fmask=0077,nosuid,nodev -L "LABEL" /data'
```

No automatic boot mount is required. Official reference: [udisksctl unlock and mount](https://storaged.org/doc/udisks2-api/latest/udisksctl.1.html). The [installation procedure](../install.md) covers first installation and live-environment storage steps.

## Before running commands

Commands run in the installed NixOS session as the normal user. Commands explicitly using `su -c` request root authentication. Project-relative tasks run from the repository root.

## Apply native configuration edits

For edits to the machine-local configuration in `/etc/nixos`, run the following from the directory containing the local flake. The local flake provides a `nixosConfigurations` entry matching the current hostname:

```bash
    su -c 'nixos-rebuild switch --flake path:.'
```

For edits to shared `system/` or `settings/` sources in a public checkout, publish the source changes and then use [Update the desktop input and apply it](#update-the-desktop-input-and-apply-it) to refresh the local lock and rebuild. Rebuilding with an unchanged locked GitHub input does not apply checkout edits.

A successful rebuild applies system configuration and unlocked GNOME and Firefox defaults in `settings/`. Continuation depends on the rebuild result. Existing user preferences take precedence. GH, VLC, and VSCodium defaults seed missing user files at user-manager startup or activation; existing files remain user-owned. A new login may be needed.

From the local flake directory, the following evaluation returns the full system derivation path for the same local attribute:

```bash
    nix eval --raw "path:.#nixosConfigurations.$(uname -n).config.system.build.toplevel.drvPath"
```

Evaluation produces the derivation path; activation and application behavior require separate verification.

Official reference: [NixOS configuration](https://nixos.org/manual/nixos/stable/#sec-changing-config).

## Inspect boot storage

Where the local configuration uses separate `/boot` and `/boot/efi` filesystems, their current usage informs diagnosis of a full boot partition:

```bash
    df -h /boot /boot/efi
```

Bootloader and kernel payloads occupy boot storage; Nix store closures and retained rollback generations consume store space within the same installation. This inspection reports usage and leaves generations and store contents intact.

## Garbage collection and rollback retention

Ordinary garbage collection removes unreferenced store objects while preserving retained profile generations and their rollback history. Both commands below work from any directory and request the root password through `su`.

```bash
    su -c 'nix-collect-garbage'
```

The following removes every other generation from only the system profile, keeping its current generation, then collects unreferenced packages and dependencies. Rollback to the removed system generations is lost.

```bash
    su -c 'nix-env --profile /nix/var/nix/profiles/system --delete-generations old && nix-collect-garbage'
```

Other roots can still retain store objects, so the amount of space reclaimed is not guaranteed.

Official documentation: [garbage collection](https://nix.dev/manual/nix/2.34/command-ref/nix-collect-garbage.html), [profile generation deletion](https://nix.dev/manual/nix/2.34/command-ref/nix-env/delete-generations.html).

## Install or uninstall a native application

[NixOS package search](https://search.nixos.org/packages) identifies package attributes. For machine-specific packages, edit `environment.systemPackages` in the local configuration, with `pkgs` available to the module, then [apply the local edit](#apply-native-configuration-edits).

The shared desktop baseline has its own package list:

```bash
    codium ./system/desktop-features.nix
```

For example, `gnumake` is already in that shared `environment.systemPackages = with pkgs; [ ... ]` list and supplies `make`. Shared baseline edits require publication and an input update as described in [Apply native configuration edits](#apply-native-configuration-edits). Module-managed features use their existing module options. User profiles and [one-off tools](#one-off-tools-from-github-flakes) provide separate alternatives.

Official references: [package management](https://nixos.org/manual/nixos/stable/#sec-package-management), [configuration and module syntax](https://nixos.org/manual/nixos/stable/#sec-configuration-syntax).

## Update the desktop input and apply it

This is the whole-system update procedure, including Firefox Nightly. The host configuration may set `system.autoUpgrade.enable = false`; the NixOS upstream default is also `false`, and the shared module does not select a scheduled-upgrade policy. Manual flake updates and rebuilds remain available; disabling scheduled upgrades does not permanently lock package versions.

The project's default Nixpkgs input targets the `nixos-26.05` release branch; the machine-local `/etc/nixos/flake.lock` records the resolved snapshots of that machine's configured inputs. Refreshing Nixpkgs advances all selected system packages to the versions and patches provided by the refreshed snapshot, without editing individual package versions. A rebuild with an unchanged lock uses the locked revisions.

Firefox Nightly comes from the `firefox-nightly` flake input, nested under `desktop` in the machine configuration. The same all-input refresh advances its packaging source alongside Nixpkgs, so an available newer Nightly build is included in the same whole-system update and activation.

Updates follow the configured release and packaging sources. Security maintenance depends on a supported release and fixes available in those sources. Moving to a newer release branch is a separate, deliberate configuration change guided by its release notes.

Local hardware, accounts, storage, boot settings, and `system.stateVersion` remain owned by the machine configuration. Shared-source edits in an unpublished checkout become available to the GitHub `desktop` input only after publication; refreshing that input retrieves published source, not local checkout edits.

Run each command from any directory in the installed session. Commands using `su -c` request the root password.

1. Before updating, save work, make an independent backup of the coherent local configuration source and its matching `flake.lock`, and confirm a known-good boot generation and a usable recovery path. Keep credentials outside flake sources: source files copied into the Nix store can be readable by other local users, and published source is public. Then refresh all inputs:

    ```bash
    cd /etc/nixos && su -c 'nix flake update'
    ```

    This refreshes all local flake inputs, including the GitHub desktop input, Nixpkgs, and the nested Nightly packaging input. It writes the machine-local `flake.lock` and may download source into the Nix store and caches; it does not activate a system generation.

2. Build the updated system as the normal user:

    ```bash
    cd /etc/nixos && nixos-rebuild build --flake path:. --no-link
    ```

    This creates the system build in the Nix store and may download or build dependencies. It does not activate the system; `--no-link` avoids a local `result` symlink. A successful build establishes buildability, not runtime correctness. If the build fails, the new generation has not been applied, but the lockfile has already changed.

3. After a successful build, review the intended source, lockfile, and package changes. Only when ready to allow runtime changes, activate:

    ```bash
    cd /etc/nixos && su -c 'nixos-rebuild switch --flake path:.'
    ```

    With unchanged source and lock, activation can reuse the completed build. Switching may restart services and interrupt work; activation can partially fail, so inspect its result before continuing.

4. Fully quit and restart Firefox to run the newly installed browser version. Reboot manually when required to use changed kernel, driver, initrd, or other boot-time components. Choose these interruptions within the maintenance window.

Project updates can change unlocked Firefox defaults; existing profile preferences continue to take precedence. Starting the new browser can migrate profile data, which a system rollback does not restore. User-managed toolchains and separately installed applications retain their own update workflows.

To abandon a failed or unwanted attempt, restore the coherent configuration source and matching lockfile from the independent backup before rebuilding. A known-good boot generation provides a system recovery path, but switching or rolling back generations does not restore mutable user files or databases; those require their own backups.

The [four-state update model](../tutorial/nix.md#11-manual-updates-across-four-kinds-of-state) separates input selection, artifacts, activation, and running data. [Generations and garbage collection](../tutorial/readme.md#10-recovery-and-garbage-collection) explain retention and recovery limits; retaining software does not back up mutable profiles.

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

Verification in a new terminal uses `type fnm`, `type z`, `node --version`, and the Git branch prompt. Moving between projects with `.node-version` or `.nvmrc` files exercises version switching; `node --version` confirms the result. Switching requires installed versions. The system provides fnm and Bash integration; Node versions and additional user tools remain user-managed. GNOME owns the graphical session, while Linux accounts and system configuration own authority and Bash. Console, Kitty, and VSCodium terminals share this shell setup; Kitty and VSCodium still require a graphical session. Administration uses root authentication through `su`.

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

The complete preset and the separately selected KeePass policy provide `keepass-local` for the existing `$HOME/.logins/KeePass.exe`. The launcher becomes available after [project activation](#apply-native-configuration-edits) and runs as the normal user:

```bash
    keepass-local
```

The launcher supplies Nix-managed GTK 2 libraries only to that Mono process, preserving any existing `LD_LIBRARY_PATH`, and forwards command-line arguments unchanged. The KeePass executable and database remain in their existing locations; browser integration remains separately managed. Direct `mono KeePass.exe` launches use the caller's environment.

This targets the GTK color-scheme warning; Auto-Type compatibility is a separate concern. Runtime verification remains pending and requires checking the warning and appearance after launch.

Source: [system/keepass.nix](keepass.nix).
