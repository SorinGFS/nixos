# NixOS setup

NixOS 26.05 with GNOME personal setup.
The machine-local flake supplies the host, hardware and lock after [installation](./install.md).

## Flake integration

Host module from [flake.nix](flake.nix): `nixosModules.default`. Existing host flakes with their own `nixpkgs` input:

```nix
inputs.desktop.url = "github:SorinGFS/nixos";
inputs.desktop.inputs.nixpkgs.follows = "nixpkgs";
```

Host output binding: `inputs` in the host's `outputs` function; module list: `inputs.desktop.nixosModules.default` in `nixpkgs.lib.nixosSystem`.

## Configuration

Target: `/etc/nixos/flake.nix`. Backup scope: its source and matching lock.

Build context: normal user.

```bash
cd /etc/nixos && nixos-rebuild build --flake path:. --no-link
```

Build review precedes activation with root authentication. Switching may restart services:

```bash
cd /etc/nixos && su -c 'nixos-rebuild switch --flake path:.'
```

## Updates

All inputs, including Firefox Nightly, are refreshed; `/etc/nixos/flake.lock` pins the selected revisions. A shared-source change requires publication and a refreshed GitHub input before the consumer sees it; an unchanged lock does not fetch a new commit.

```bash
cd /etc/nixos && su -c 'nix flake update'
```

Build and activation use the commands above.

## References

- [Modules](modules/readme.md)
- [Tutorial](tutorial/readme.md)
