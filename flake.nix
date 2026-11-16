# Define public inputs and the reusable NixOS desktop configuration.
{
    description = "Reusable NixOS desktop configuration";
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
        firefox-nightly.url = "github:nix-community/flake-firefox-nightly";
        firefox-nightly.inputs.nixpkgs.follows = "nixpkgs";
    };
    outputs = inputs: import ./modules/exports.nix inputs;
}
