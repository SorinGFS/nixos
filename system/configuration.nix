# Assemble the public desktop modules, complete preset and native checks.
desktopInputs@{ self, nixpkgs, ... }:
{
    nixosModules = {
        # Pass project inputs to composed desktop modules through a namespaced argument.
        desktop = {
            imports = [ ./desktop.nix ];
            _module.args.desktopInputs = desktopInputs;
        };
        root-administration = import ./root-administration.nix;
        power = import ./power.nix;
        virtualisation = import ./virtualisation.nix;
        keepass = import ./keepass.nix;

        # Retain the complete preset as the default public module.
        default = {
            imports = [
                self.nixosModules.desktop
                self.nixosModules.root-administration
                self.nixosModules.power
                self.nixosModules.virtualisation
                self.nixosModules.keepass
            ];
        };
    };

    # Exercise real consumer configurations without defining an installed host.
    checks.x86_64-linux = import ./checks.nix { inherit self nixpkgs; system = "x86_64-linux"; };
}
