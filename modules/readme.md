# NixOS modules

This collection exports reusable NixOS modules used in a flake.

## Integration and ownership

[exports.nix](exports.nix) exposes reusable module compositions. The `desktop` and `default` wrappers pass the root inputs as `_module.args.desktopInputs`; [Firefox](applications/firefox/readme.md) consumes its Nightly input. The complete `nixosModules.default` imports the desktop, [power](power/readme.md), [libvirt](virtualisation/libvirt/readme.md), and [KeePass](applications/keepass/readme.md) policies. The separately exported `desktop`, `power`, `virtualisation`, and `keepass` modules permit narrower composition. Desktop alone disables sudo, but omits power policy, libvirt, and KeePass including its shortcut. The complete preset enables NetworkManager and libvirt, disables sudo and sleep, and defaults the CPU governor to performance.

See [NixOS module writing](https://nixos.org/manual/nixos/stable/#sec-writing-modules).

## References

- [Nix](nix/readme.md)
- [Fonts](fonts/readme.md)
- [Power](power/readme.md)
- [Security](security/readme.md)
- [Services](services/readme.md)
- [Shell](shell/readme.md)
- [Desktop](desktop/readme.md)
- [Applications](applications/readme.md)
- [Virtualisation](virtualisation/readme.md)
