# Select GNOME pinentry and avoid its competing SSH agent only with GNOME.
{ config, lib, pkgs, ... }:
{
    config = lib.mkIf config.services.desktopManager.gnome.enable {
        services.gnome.gcr-ssh-agent.enable = false;
        programs.gnupg.agent.pinentryPackage = pkgs.pinentry-gnome3;
    };
}
