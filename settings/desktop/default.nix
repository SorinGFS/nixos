# Define desktop and keyboard defaults, retaining the schema's explicit types.
{ lib, ... }:
let
    values = builtins.fromJSON (builtins.readFile ./index.json);
    group = import ../group.nix { inherit lib; };
    g = lib.gvariant;
    typed = values // {
        "org/gnome/desktop/session/idle-delay" = g.mkUint32 values."org/gnome/desktop/session/idle-delay";
        "org/gnome/desktop/privacy/old-files-age" = g.mkUint32 values."org/gnome/desktop/privacy/old-files-age";
        "org/gnome/desktop/input-sources/sources" = if values."org/gnome/desktop/input-sources/sources" == [ ] then g.mkEmptyArray (g.type.tupleOf [ g.type.string g.type.string ]) else g.mkArray (map g.mkTuple values."org/gnome/desktop/input-sources/sources");
        "org/gnome/desktop/input-sources/xkb-options" = if values."org/gnome/desktop/input-sources/xkb-options" == [ ] then g.mkEmptyArray g.type.string else g.mkArray values."org/gnome/desktop/input-sources/xkb-options";
    };
in
{
    programs.dconf.profiles.user.databases = [ { settings = group typed; } ];
}
