# Reference the portable wallpaper asset through its immutable store path.
{ ... }:
let
    values = builtins.fromJSON (builtins.readFile ./index.json);
    uri = "file://${./. + "/${values.file}"}";
in
{
    programs.dconf.profiles.user.databases = [ {
        settings."org/gnome/desktop/background" = {
            picture-options = values."picture-options";
            picture-uri = uri;
            picture-uri-dark = uri;
        };
    } ];
}
