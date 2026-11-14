# Restore favorites, enabled extensions and the explicitly ordered app grid.
{ lib, ... }:
let
    values = builtins.fromJSON (builtins.readFile ./index.json);
    g = lib.gvariant;
    apps = values."org/gnome/shell/app-picker-layout";
    # The app grid is an array of dictionaries whose positions are variants.
    page = if apps == [ ] then g.mkEmptyArray (g.type.dictionaryEntryOf g.type.string g.type.variant) else g.mkArray (lib.imap0 (position: app:
        g.mkDictionaryEntry app (g.mkVariant (g.mkArray [
            (g.mkDictionaryEntry "position" (g.mkVariant (g.mkInt32 position)))
        ]))
    ) apps);
in
{
    programs.dconf.profiles.user.databases = [ {
        settings = (import ../group.nix { inherit lib; }) (values // {
            "org/gnome/shell/app-picker-layout" = g.mkArray [ page ];
        });
    } ];
}
