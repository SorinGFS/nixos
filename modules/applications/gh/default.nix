# Seed missing GitHub CLI preferences without managing authentication.
{ lib, pkgs, ... }:
let
    values = builtins.fromJSON (builtins.readFile ./index.json);
    # JSON is valid YAML; escape C-style arguments and literal tmpfiles percent markers.
    content = builtins.toJSON values + "\n";
    argument = lib.replaceStrings [ "\\" "\n" "%" ] [ "\\\\" "\\n" "%%" ] content;
in
{
    environment.systemPackages = [ pkgs.gh ];
    # The ':' mode prefix preserves permissions when the file already exists.
    systemd.user.tmpfiles.rules = [ "f %h/.config/gh/config.yml :0644 - - - ${argument}" ];
}
