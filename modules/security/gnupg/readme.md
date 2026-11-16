# GnuPG and SSH agent

[default.nix](default.nix) installs GnuPG, enables its agent and SSH support, and disables the separate OpenSSH agent to avoid competing agents. When GNOME is enabled, [gnome.nix](gnome.nix) disables the GCR SSH agent and selects GNOME pinentry without enabling GNOME. See [NixOS configuration syntax](https://nixos.org/manual/nixos/stable/#sec-configuration-syntax).
