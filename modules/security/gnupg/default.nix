# Use the GnuPG agent for GPG and SSH authentication.
{ pkgs, ... }:
{
    imports = [ ./gnome.nix ];
    programs.ssh.startAgent = false;
    programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
    };
    environment.systemPackages = [ pkgs.gnupg ];
}
