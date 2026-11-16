# KeePass launcher

The optional policy provides `keepass-local` for the existing `$HOME/.logins/KeePass.exe`. Run as the normal user:

```bash
keepass-local
```

The launcher supplies Nix-managed GTK 2 libraries only to its Mono process, preserving an existing `LD_LIBRARY_PATH`, adds xdotool to that process's PATH and forwards arguments. The executable, database and browser integration remain user-managed. Direct Mono launches use the caller's environment.

This targets a GTK color-scheme warning; verify appearance and warning behavior locally. Auto-Type is a separate concern and no Wayland fix is guaranteed. Its GNOME child supplies the shortcut only when GNOME is enabled. See [Nixpkgs manual](https://nixos.org/manual/nixpkgs/stable/).

- [GNOME shortcut](gnome/readme.md)
