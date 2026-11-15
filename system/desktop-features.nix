# Configure desktop services and terminal-font dependencies.
{ pkgs, ... }:
{
    # Use GNOME's existing portals for optional Flatpak applications.
    services.flatpak.enable = true;

    # Keep the core shell and selected applications without the optional GNOME suite.
    services.gnome.core-apps.enable = false;
    environment.gnome.excludePackages = [ pkgs.gnome-tour ];

    # Select Kitty for applications that use the proposed XDG terminal launcher.
    xdg.terminal-exec = {
        enable = true;
        settings.default = [ "kitty.desktop" ];
        settings.GNOME = [ "kitty.desktop" ];
    };
    # Provide system-wide defaults without changing any user configuration.
    environment.etc."xdg/kitty/kitty.conf".text = builtins.concatStringsSep "\n" [
        "font_family MesloLGM Nerd Font Mono"
        "font_size 11.0"
        "cursor_shape beam"
        "copy_on_select clipboard"
        "confirm_os_window_close 0"
        "mouse_map right press ungrabbed paste_from_clipboard"
        ""
    ];
    # Prefer Files for opening folders.
    xdg.mime.defaultApplications."inode/directory" = [ "nautilus.desktop" "org.gnome.Nautilus.desktop" ];

    # Keep the audio backend independently of remote-desktop support.
    services.pipewire.enable = true;

    # Disable only the unwanted optional GNOME services.
    services.gnome.gnome-online-accounts.enable = false;
    services.geoclue2.enable = false;
    services.gnome.localsearch.enable = false;
    services.gnome.tinysparql.enable = false;
    services.gnome.gnome-remote-desktop.enable = false;
    services.gnome.gnome-user-share.enable = false;
    services.gnome.rygel.enable = false;
    services.dleyna.enable = false;
    services.gnome.gnome-initial-setup.enable = false;
    services.gnome.gnome-browser-connector.enable = false;

    # Let the user GPG agent own SSH authentication while retaining GNOME Keyring.
    services.gnome.gcr-ssh-agent.enable = false;
    programs.ssh.startAgent = false;
    programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
        pinentryPackage = pkgs.pinentry-gnome3;
    };

    # Retain loader support for fnm's downloaded Node binaries.
    programs.nix-ld.enable = true;

    # Install the selected family and enable its GNOME preference backend.
    programs.dconf.enable = true;
    fonts.packages = [ pkgs.nerd-fonts.meslo-lg ];
    environment.systemPackages = with pkgs; [
        jq git gh gnumake python3 mono vlc qbittorrent vscodium ripgrep zoxide fnm
        gnupg curl coreutils unzip xz nautilus kitty tmux wl-clipboard
        gnomeExtensions.dash-to-panel
    ];
}
