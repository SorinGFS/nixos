# GitHub CLI

The module installs `gh` and seeds `~/.config/gh/config.yml` from [index.json](index.json) only when missing. It uses a fixed path independent of `XDG_CONFIG_HOME` and `GH_CONFIG_DIR`; existing writable preferences and authentication remain user-owned. User tmpfiles escapes embedded percent markers and preserves existing permissions. See [NixOS configuration syntax](https://nixos.org/manual/nixos/stable/#sec-configuration-syntax) and [GitHub CLI configuration](https://cli.github.com/manual/gh_config).
