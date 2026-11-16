# Apply the configured layout to the first monitor and preserve typed animation extents.
{ lib, pkgs, ... }:
let
    values = builtins.fromJSON (builtins.readFile ./index.json);
    g = lib.gvariant;
    extent = values."animate-appicon-hover-animation-extent";
    # Panel layout objects are serialized strings; numeric values retain schema types.
    typed = lib.mapAttrs (key: value:
        if key == "animate-appicon-hover-animation-extent" then
            if extent == { } then g.mkEmptyArray (g.type.dictionaryEntryOf g.type.string g.type.int32)
            else g.mkArray (lib.mapAttrsToList (name: number: g.mkDictionaryEntry name (g.mkInt32 number)) extent)
        else if builtins.elem key [ "panel-anchors" "panel-element-positions" "panel-lengths" "panel-positions" "panel-sizes" ] then builtins.toJSON value
        else if key == "trans-panel-opacity" then g.mkDouble value
        else if builtins.isInt value then g.mkInt32 value
        else value
    ) values;
in
{
    environment.systemPackages = [ pkgs.gnomeExtensions.dash-to-panel ];
    programs.dconf.profiles.user.databases = [ { settings."org/gnome/shell/extensions/dash-to-panel" = typed; } ];
}
