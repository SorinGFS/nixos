# Define public inputs and the reusable NixOS desktop configuration.
{
    description = "Reusable NixOS desktop configuration";
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
        firefox-nightly.url = "github:nix-community/flake-firefox-nightly";
        firefox-nightly.inputs.nixpkgs.follows = "nixpkgs";
    };
    outputs = { firefox-nightly, ... }: {
        # Supply the Firefox input to the reusable desktop modules.
        nixosModules.default = { ... }: {
            imports = [ ./system/configuration.nix ];
            _module.args.firefox-nightly = firefox-nightly;
        };
    };
}
