# NixOS setup

A fresh [installation](./install.md) sets up NixOS 26.05 with GNOME and applies this flake's full default preset.
The following sections cover flake integration and maintenance for systems with an existing `/etc/nixos` configuration.

## Flake integration

Host module from [flake.nix](flake.nix): `nixosModules.default`. Existing host flakes with their own `nixpkgs` input:

```nix
inputs.desktop.url = "github:SorinGFS/nixos";
inputs.desktop.inputs.nixpkgs.follows = "nixpkgs";
```

Host output binding: `inputs` in the host's `outputs` function; module list: `inputs.desktop.nixosModules.default` in `nixpkgs.lib.nixosSystem`.

Reference: [Flake inputs and `follows` (Nix Reference Manual)](https://nix.dev/manual/nix/2.34/command-ref/new-cli/nix3-flake.html#flake-inputs).

## Configuration

After integration, the following command applies the configuration:

```bash
cd /etc/nixos && su -c 'nixos-rebuild switch --flake path:.'
```

## Updates

This command refreshes all inputs in `/etc/nixos/flake.lock`:

```bash
cd /etc/nixos && su -c 'nix flake update'
```

The rebuild under [Configuration](#configuration) applies the updated inputs.

## References

- [Modules](modules/readme.md)
- [Tutorial](tutorial/readme.md)
