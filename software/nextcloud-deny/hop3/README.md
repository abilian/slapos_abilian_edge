# Nextcloud, current, with apps and updates kept out of the code

The golden recipe, with four changes:

- **Nextcloud 35.0.2, checked by sha256**, in place of 28.0.2, whose series has had no security fix since the end of 2024. The script downloads the zip, since a SlapOS build has `unzip` and no `bzip2`.
- **Apps from the app store go to `custom_apps/`, a volume.** Every deploy replaces the code, and an app installed beside it would go with it.
- **The web updater is off** (`upgrade.disable-web`). It would move the code ahead of the recipe's version, and the next deploy would put the older code back on the newer database, which Nextcloud refuses to run.
- **`[proxy] deny` also covers the recipe's own files.**

The name also avoids a clash with `software/nextcloud` in SlapOS, the release upstream maintains.
