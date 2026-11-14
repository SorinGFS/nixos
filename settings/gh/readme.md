# GitHub CLI preferences

Edits to `settings/gh/index.json` change initial GitHub CLI preferences after [project activation](../../system/readme.md#apply-native-configuration-edits). User tmpfiles seeds `~/.config/gh/config.yml` when missing as a writable user-owned file. Existing files, subsequent user edits and authentication retain their values. The seed destination is fixed at this standard path, independent of `XDG_CONFIG_HOME` and `GH_CONFIG_DIR`.

Official documentation: [GitHub CLI configuration](https://cli.github.com/manual/gh_config).
