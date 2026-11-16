# Security

The desktop composition imports [sudo.nix](sudo.nix), which disables sudo; establish a root password and working `su` access before applying it. Authentication and accounts remain host-owned. See [NixOS modules](https://nixos.org/manual/nixos/stable/#sec-writing-modules).

- [GnuPG and SSH agent](gnupg/readme.md)
