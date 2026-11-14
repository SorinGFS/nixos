# Supply unlocked Firefox defaults without writing profile preferences.
{ lib, ... }:
let
    values = builtins.fromJSON (builtins.readFile ./index.json);
in
{
    # AutoConfig covers preferences excluded by enterprise policies without locking them.
    programs.firefox.autoConfig = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value:
        "defaultPref(${builtins.toJSON name}, ${builtins.toJSON value});"
    ) values);
}
