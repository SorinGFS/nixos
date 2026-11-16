# Applications

Application modules own their packages and native defaults. The [desktop composition](../desktop/readme.md) selects these applications; [KeePass](keepass/readme.md) is separately selectable.

The shared [packages.nix](packages.nix) selects fd, jq, git, gnumake, python3, mono, mpv, qbittorrent, ripgrep, zoxide, fnm, curl, coreutils, unzip, xz, tmux, wl-clipboard and pandoc. Mono remains in the baseline without KeePass. FFmpeg and ImageMagick custom-library builds and integration remain future work; the existing rcon workflow creates Debian packages.

For host-only packages add attributes to the local `environment.systemPackages` with `pkgs` available to the module. To edit shared selections from the project root:

```bash
codium ./modules/applications/packages.nix
```

For example, `gnumake` in that list provides `make`. A shared-source edit must be published and the consumer input refreshed before a GitHub-based host sees it; local host edits can be applied directly. Use native module options for option-managed applications rather than editing the baseline. User profiles and [one-off tools](../nix/readme.md#one-off-tools) are separate alternatives. Follow the [application workflow](../readme.md#apply-local-configuration-and-update-the-whole-system). [NixOS package management](https://nixos.org/manual/nixos/stable/#sec-package-management) and [package search](https://search.nixos.org/packages) describe selection.

## tmux sessions

```bash
tmux new -s work
```

Ctrl+b then d detaches; reconnect with `tmux attach -t work`. Ctrl+b then `%` splits left/right, `"` splits top/bottom, and an arrow selects a neighboring pane.

## Guides

- [Files](files/readme.md)
- [Firefox Nightly](firefox/readme.md)
- [GitHub CLI](gh/readme.md)
- [KeePass](keepass/readme.md)
- [Kitty](kitty/readme.md)
- [VSCodium](vscodium/readme.md)
