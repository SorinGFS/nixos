# Group full dconf key paths into schema sections for the NixOS dconf module.
{ lib }: values:
lib.foldl' lib.recursiveUpdate { } (lib.mapAttrsToList (path: value:
    let
        parts = lib.splitString "/" path;
        key = lib.last parts;
        schema = lib.concatStringsSep "/" (lib.init parts);
    # Empty plain lists in these schemas are string arrays; complex arrays are typed by their modules.
    in { ${schema}.${key} = if builtins.isList value && value == [ ] then lib.gvariant.mkEmptyArray lib.gvariant.type.string else value; }
) values)
