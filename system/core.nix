# Configure shared GNOME, networking, locale, Bash and manual updates.
{ lib, pkgs, ... }:
{
    # Enable the flake commands used to build and update this configuration.
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    # Deduplicate identical store files without deleting rollback generations.
    nix.settings.auto-optimise-store = true;
    # Connect the desktop through NetworkManager.
    networking.networkmanager.enable = true;

    # Keep locale and keyboard choices portable.
    time.timeZone = lib.mkDefault "Europe/Bucharest";
    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
    services.xserver.xkb.layout = lib.mkDefault "us";
    console.keyMap = lib.mkDefault "us";

    # Start the GNOME graphical desktop.
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;

    # Preserve the NixOS colored prompt and title while adding the Git branch.
    programs.bash.promptInit = ''
        if [ "$TERM" != "dumb" ] || [ -n "$INSIDE_EMACS" ]; then
            git_branch_prompt=
            if [ -r "${pkgs.git}/share/git/contrib/completion/git-prompt.sh" ]; then
                source "${pkgs.git}/share/git/contrib/completion/git-prompt.sh"
                git_branch_prompt='$(__git_ps1 " (%s)")'
            fi
            PROMPT_COLOR="1;31m"
            ((UID)) && PROMPT_COLOR="1;32m"
            if [ -n "$INSIDE_EMACS" ]; then
                PS1="\n\[\033[$PROMPT_COLOR\][\u@\h:\w$git_branch_prompt]\\$\[\033[0m\] "
            else
                PS1="\n\[\033[$PROMPT_COLOR\][\[\e]0;\u@\h: \w\a\]\u@\h:\w$git_branch_prompt]\\$\[\033[0m\] "
            fi
            if [ "$TERM" = "xterm" ]; then
                PS1="\[\033]2;\h:\u:\w\007\]$PS1"
            fi
            unset git_branch_prompt
        fi
    '';

    # Initialize the user-managed Node toolchain and directory navigation in interactive shells.
    programs.bash.interactiveShellInit = ''
        eval "$(${pkgs.fnm}/bin/fnm env --use-on-cd --shell bash)"
        if command -v zoxide >/dev/null 2>&1; then
            eval "$(zoxide init bash)"
        fi
    '';

    # Keep system updates under manual operator control.
    system.autoUpgrade.enable = false;
}
