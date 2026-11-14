# VLC preferences

Edits to `settings/vlc/index.json` change initial VLC preferences after [project activation](../../system/readme.md#apply-native-configuration-edits). User tmpfiles seeds `~/.config/vlc/vlcrc` when missing as a writable user-owned file. Existing files and later GUI edits retain their values; source changes affect future seeds. The seed destination is fixed at this standard path, independent of `XDG_CONFIG_HOME`.

Official documentation: [VLC desktop guide](https://docs.videolan.me/vlc-user/desktop/3.0/en/).
