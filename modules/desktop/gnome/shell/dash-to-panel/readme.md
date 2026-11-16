# Dash to Panel

This module installs the extension and supplies unlocked defaults. [default.nix](default.nix) defines the first-monitor layout as native schema attributes. Five layout maps are serialized with `builtins.toJSON` to the strings expected by the extension; animation extents and numeric values use explicit GVariant types. Existing user overrides take precedence. A new login may be needed.

Inspect and control the extension as the logged-in user:

```bash
gnome-extensions list
```

```bash
gnome-extensions info dash-to-panel@jderose9.github.com
```

```bash
gnome-extensions enable dash-to-panel@jderose9.github.com
```

```bash
gnome-extensions prefs dash-to-panel@jderose9.github.com
```

```bash
gnome-extensions disable dash-to-panel@jderose9.github.com
```

Disabling changes user state but leaves the packaged extension and declarative defaults in place. For permanent removal, omit the Shell child import, which removes both the package and its defaults, and remove its UUID from the Shell settings; activate and log in again. See [Nixpkgs manual](https://nixos.org/manual/nixpkgs/stable/) and [Dash to Panel](https://github.com/home-sweet-gnome/dash-to-panel).
