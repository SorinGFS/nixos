# GNOME desktop preferences

These session commands run as the logged-in user in the [system guide's standard user context](../../system/readme.md#before-running-commands).

The following commands report current session values:

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

These example commands change the running session immediately:

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

Edits to `settings/desktop/index.json` change defaults for future users after [project activation](../../system/readme.md#apply-native-configuration-edits). The defaults are applied through the user dconf profile. [Files](../files/readme.md), [GNOME Shell](../shell/readme.md), and [Dash to Panel](../dash-to-panel/readme.md) have separate source files; the [wallpaper guide](../wallpaper/readme.md) covers its asset and filename.

Capturing GUI changes in project sources is a separate authoring step. Existing user values override defaults; individual `gsettings set` commands change the current session. Privacy configuration carries preference values exclusively; recent-file and usage data remain local.

Official references: [GSettings CLI](https://github.com/GNOME/glib/blob/main/docs/reference/gio/gsettings.rst), [GNOME desktop schemas](https://gitlab.gnome.org/GNOME/gsettings-desktop-schemas).


## Display scaling

```bash
gnome-control-center display
```

The selected display's **Scale → 200%** setting takes effect after application and confirmation. GNOME's monitor configuration remains user-managed and requires manual setup after installation. Display scaling controls the whole display; font scaling controls text.

Official documentation: [GNOME display settings](https://help.gnome.org/users/gnome-help/stable/look-resolution.html.en).
