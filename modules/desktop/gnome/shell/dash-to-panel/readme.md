# Dash to Panel

This module installs the extension and supplies unlocked defaults. The first-monitor layout in [index.json](index.json) stores five panel layout maps as JSON objects; the adapter serializes them as the strings expected by the extension and retains typed animation extents and numeric values. Existing user overrides take precedence. Apply source changes through the [local update workflow](../../../../readme.md#apply-local-configuration-and-update-the-whole-system); a new login may be needed.

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

Disabling changes user state but leaves the packaged extension and declarative defaults in place. For permanent removal, omit the Shell child import, which removes both the package and its defaults, and remove its UUID from the Shell JSON; activate and log in again. See [Nixpkgs manual](https://nixos.org/manual/nixpkgs/stable/) and [Dash to Panel](https://github.com/home-sweet-gnome/dash-to-panel).
