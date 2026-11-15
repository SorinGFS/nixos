# NixOS terminal cookbook

NixOS 26.05 with GNOME. For installation, see [install.md](install.md); this cookbook documents the repository's configuration.

## Setup rationale

- **Native source of truth:** [flake.nix](flake.nix) declares inputs and delegates module exports and checks to [system/configuration.nix](system/configuration.nix), composed from focused system modules and [settings sources](settings/default.nix). The installer integrates it into a machine-local NixOS flake; existing installations can [integrate it manually](system/readme.md#integrate-the-desktop-module). Apply changes through that local configuration.
- **System responsibilities:** The local configuration owns host identity, accounts, boot, storage, hardware, and state version. [core.nix](system/core.nix) owns GNOME, networking, locale, Bash initialization and manual updates; [desktop-features.nix](system/desktop-features.nix) owns shared desktop services and packages. The [complete preset and selectable policies](system/readme.md#selecting-policies) separate administration, power, virtualization and external KeePass integration.
- **Session versus shell:** GNOME provides the graphical session; Linux accounts and system configuration own user authority and Bash. Linux console access is independent of GNOME. The console, Kitty, and VSCodium's embedded terminal share Bash setup; Kitty and VSCodium still require a graphical session. Administration uses root authentication through `su`.
- **Manual updates:** Scheduled unattended system upgrades are disabled so the operator chooses the maintenance window. [Update the whole system, including Firefox Nightly](system/readme.md#update-the-desktop-input-and-apply-it), by refreshing the local flake inputs, building, and then choosing when to activate.
- **User toolchain:** The system provides fnm and Bash integration for project-based Node version selection across terminals. Node versions and additional user tools are user-managed.
- **Defaults versus preferences:** Settings modules generate unlocked GNOME defaults and seed missing GH, VLC, and VSCodium files. This deliberately preserves GUI changes: user overrides win, and existing seeded files remain user-owned.
- **One editor package:** The [VSCodium customization](settings/vscodium/default.nix) serves both system installation and extension provisioning. Desktop-only `--force-user-env` counters the CLI launcher's environment-resolution bypass; terminal launches retain the inherited project selection.

## Index

### System

- [System configuration, packages and upgrades](system/readme.md)
- [Integrate the desktop module](system/readme.md#integrate-the-desktop-module)
- [Select desktop policies](system/readme.md#selecting-policies)
- [Native configuration checks](system/readme.md#native-checks)
- [Update the whole system, including Firefox Nightly](system/readme.md#update-the-desktop-input-and-apply-it)
- [One-off tools from GitHub flakes](system/readme.md#one-off-tools-from-github-flakes)
- [Unlock and mount data storage](system/readme.md#unlock-and-mount-data-storage)
- [Boot storage inspection](system/readme.md#inspect-boot-storage)
- [Bash and console access](system/readme.md#bash-and-console-access)
- [Kitty terminal](system/readme.md#kitty-terminal-preferences)
- [tmux sessions](system/readme.md#tmux-sessions)
- [Planned media and document tools](system/readme.md#planned-media-and-document-tools)
- [KeePass launcher](system/readme.md#launch-the-existing-keepass-application-with-gtk-2-libraries)

### Settings

- [Native settings defaults and validation](settings/readme.md)

#### Desktop

- [GNOME desktop preferences](settings/desktop/readme.md)
- [Files preferences](settings/files/readme.md)
- [GNOME Shell preferences](settings/shell/readme.md)
- [Dash to Panel](settings/dash-to-panel/readme.md)
- [Wallpaper](settings/wallpaper/readme.md)

#### Applications

- [Firefox Nightly](settings/firefox/readme.md)
- [VSCodium](settings/vscodium/readme.md)
- [VSCodium desktop launch environment](settings/vscodium/readme.md#desktop-launch-environment)
- [GitHub CLI](settings/gh/readme.md)
- [VLC](settings/vlc/readme.md)
