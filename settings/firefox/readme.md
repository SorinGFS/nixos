# Firefox Nightly

## X11 compatibility

The native Firefox Nightly launcher in [system/firefox.nix](../../system/firefox.nix) unsets `WAYLAND_DISPLAY` and sets `GDK_BACKEND=x11` and `MOZ_ENABLE_WAYLAND=0` for Firefox and its child processes, including launches from the desktop or `firefox-nightly` command. The session environment and generic default-browser launchers retain their settings. The change takes effect after [project activation](../../system/readme.md#apply-native-configuration-edits) and a Firefox restart.

The user accepts the security tradeoff: on a Wayland desktop, Xwayland provides weaker isolation between X11 clients than native Wayland, so other X11 clients may be able to observe or interfere with Firefox input and windows. The compatibility setting is scoped to Firefox.

## Change Firefox defaults

Edits to `settings/firefox/index.json` take effect after [project activation](../../system/readme.md#apply-native-configuration-edits) and a Firefox restart. These are unlocked AutoConfig defaults: existing profile preferences, including an existing `user.js`, retain their values and take precedence. Resetting an individual preference in `about:config` selects its default.

Official documentation: [Firefox AutoConfig](https://support.mozilla.org/en-US/kb/customizing-firefox-using-autoconfig).
