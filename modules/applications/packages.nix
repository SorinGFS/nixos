# Install the remaining shared desktop command-line and application packages.
{ pkgs, ... }:
{
    environment.systemPackages = with pkgs; [
        fd jq git gnumake python3 mono mpv qbittorrent ripgrep zoxide fnm
        curl coreutils unzip xz tmux wl-clipboard pandoc
    ];
}
