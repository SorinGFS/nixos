# Configure the interactive Bash prompt and shell integrations.
{ pkgs, ... }:
{
    imports = [ ./integrations.nix ];
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

}
