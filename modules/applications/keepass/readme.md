# KeePass launcher

The optional policy provides a **KeePass** application-menu entry and the `keepass-local` command for the existing `$HOME/.logins/KeePass.exe`. The desktop entry runs the same launcher without a terminal and can be added to GNOME Favorites for Dash to Panel.

The launcher supplies Nix-managed GTK 2 libraries only to its Mono process, preserving an existing `LD_LIBRARY_PATH`, adds xdotool to that process's PATH and forwards arguments. The executable, database and browser integration remain user-managed. Direct Mono launches use the caller's environment.

This targets a GTK color-scheme warning; verify appearance and warning behavior locally. Auto-Type is a separate concern and no Wayland fix is guaranteed. Its GNOME child supplies the shortcut only when GNOME is enabled. See [Nixpkgs manual](https://nixos.org/manual/nixpkgs/stable/).

- [GNOME shortcut](gnome/readme.md)
