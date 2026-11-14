# Seed VSCodium preferences and import the extension baseline manager.
{ pkgs, ... }:
let
    values = builtins.fromJSON (builtins.readFile ./index.json);
    defaultsFile = pkgs.writeText "vscodium-default-settings.json" (builtins.toJSON values + "\n");
in
{
    imports = [ ./extensions.nix ];

    # Share one package between desktop launchers and extension provisioning.
    nixpkgs.overlays = [ (final: prev: {
        vscodium = prev.vscodium.overrideAttrs (old: {
            # Resolve the shell environment for desktop launches without altering CLI launches.
            desktopItems = map (item: item.override (args:
                let
                    # Detect upstream launcher changes instead of silently dropping the flag.
                    forceEnv = exec: assert prev.lib.hasPrefix "codium " exec;
                        "codium --force-user-env ${prev.lib.removePrefix "codium " exec}";
                in {
                    exec = forceEnv args.exec;
                    actions = prev.lib.mapAttrs (_: action:
                        if action ? exec && action.exec != null
                        then action // { exec = forceEnv action.exec; }
                        else action
                    ) (args.actions or {});
                }
            )) old.desktopItems;
        });
    }) ];

    # Credentials avoid tmpfiles' PATH_MAX limit on inline argument expansion.
    systemd.user.services.systemd-tmpfiles-setup.serviceConfig.LoadCredential = "vscodium-default-settings:${defaultsFile}";
    systemd.user.services.nixos-activation.serviceConfig.LoadCredential = "vscodium-default-settings:${defaultsFile}";

    # The ':' mode prefix preserves permissions when the file already exists.
    systemd.user.tmpfiles.rules = [ "f^ %h/.config/VSCodium/User/settings.json :0644 - - - vscodium-default-settings" ];
}
