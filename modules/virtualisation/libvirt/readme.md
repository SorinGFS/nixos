# Libvirt and virt-manager

[default.nix](default.nix) enables local libvirtd, disables its SSH proxy and imports the [virt-manager client](virt-manager.nix). The client can also connect to remote hosts. Local group membership and host access are configured separately. See [NixOS configuration syntax](https://nixos.org/manual/nixos/stable/#sec-configuration-syntax).
