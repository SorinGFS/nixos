# Dash to Panel

Project-relative source paths require the [system guide's command setup](../../system/readme.md#before-running-commands).

Official documentation: [Dash to Panel repository and preferences](https://github.com/home-sweet-gnome/dash-to-panel), [GNOME extension CLI](https://github.com/GNOME/gnome-shell/blob/main/subprojects/extensions-tool/man/gnome-extensions.rst).

## Install

The project already declares `gnomeExtensions.dash-to-panel` in the native source:

```bash
codium ./system/desktop-features.nix
```

Restoration requires `gnomeExtensions.dash-to-panel` in the existing `environment.systemPackages` list, followed by [project activation](../../system/readme.md#apply-native-configuration-edits) and a new login.

## List installed extensions and inspect state or errors

```bash
gnome-extensions list
```

```bash
gnome-extensions info dash-to-panel@jderose9.github.com
```

## Enable

```bash
gnome-extensions enable dash-to-panel@jderose9.github.com
```

## Open preferences

```bash
gnome-extensions prefs dash-to-panel@jderose9.github.com
```

The project defaults, including the first-monitor layout, are in `settings/dash-to-panel/index.json`. The five `panel-*` layout maps are JSON objects here; the Nix module serializes them to the strings expected by the extension. Source edits take effect as defaults after rebuilding; existing user overrides still win.

## Temporary deactivation

```bash
gnome-extensions disable dash-to-panel@jderose9.github.com
```

## Permanently uninstall

Permanent removal begins with deactivation, followed by removal of `gnomeExtensions.dash-to-panel` from the native package list, its UUID from `settings/shell/index.json`, and the panel settings module import from `settings/default.nix`. [Project activation](../../system/readme.md#apply-native-configuration-edits) and a new login complete removal. The native configuration exclusively owns this immutable package.

Other packaged extensions use the [native application lifecycle](../../system/readme.md#install-or-uninstall-a-native-application), including rebuilding and a new login. The commands above accept each extension's UUID from `gnome-extensions list`. Native packaging supplies the complete installation.
