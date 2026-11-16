# GNOME desktop

The module enables GNOME and GDM, disables the optional core app suite and selected services, and imports its Shell and wallpaper children, [Meslo](../../fonts/readme.md) and dconf. See [NixOS GNOME](https://nixos.org/manual/nixos/stable/#sec-gnome-enable).

[default.nix](default.nix) supplies unlocked user defaults as schema attributes. It explicitly types unsigned idle and privacy ages and keyboard source tuples and options. User keyboard settings are distinct from the host's X keyboard layout. Existing user values override defaults; GUI changes must be captured separately in source if desired. Privacy values are preferences; recent-file and usage data remain user-owned.

Inspect current values as the logged-in user:

```bash
gsettings get org.gnome.desktop.interface color-scheme
```

```bash
gsettings get org.gnome.desktop.interface enable-animations
```

```bash
gsettings get org.gnome.desktop.session idle-delay
```

```bash
gsettings get org.gnome.settings-daemon.plugins.power idle-dim
```

Change the current session independently of the source:

```bash
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
```

```bash
gsettings set org.gnome.desktop.interface enable-animations false
```

```bash
gsettings set org.gnome.desktop.session idle-delay 0
```

```bash
gsettings set org.gnome.settings-daemon.plugins.power idle-dim true
```

The [dconf backend guide](../../services/dconf/readme.md) links to typed settings owners. See [GSettings CLI](https://github.com/GNOME/glib/blob/main/docs/reference/gio/gsettings.rst).

## Display scaling

```bash
gnome-control-center display
```

Choose and confirm the desired scale, such as 200%. Monitor configuration is user-managed after installation; display scaling affects the display, while font scaling affects text. See [GNOME display settings](https://help.gnome.org/users/gnome-help/stable/look-resolution.html.en).

## Guides

- [Shell and application grid](shell/readme.md)
- [Wallpaper](wallpaper/readme.md)
