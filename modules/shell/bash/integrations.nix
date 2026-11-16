# Initialize user-managed Node versions and directory navigation in Bash.
{ pkgs, ... }:
{
    imports = [ ../../nix/ld.nix ];
    programs.bash.interactiveShellInit = ''
        eval "$(${pkgs.fnm}/bin/fnm env --use-on-cd --shell bash)"
        if command -v zoxide >/dev/null 2>&1; then
            eval "$(zoxide init bash)"
        fi
    '';
}
