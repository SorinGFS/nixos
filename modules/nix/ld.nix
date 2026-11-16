# Support dynamically linked binaries downloaded by fnm.
{ ... }:
{
    programs.nix-ld.enable = true;
}
