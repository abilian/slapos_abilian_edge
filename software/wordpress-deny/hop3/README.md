# WordPress, pinned, with the recipe's files as a deny list

The golden recipe, with four changes:

- **`[proxy] deny`.** The recipe leaves `hop3.toml` and `scripts/` in the web root, where anyone can read the shell script and run the PHP ones.
- **WordPress 7.1.4, checked by sha256**, in place of 6.4.2.
- **`AUTOMATIC_UPDATER_DISABLED`.** A fresh install turns on major updates, and one signed-out request to `/wp-cron.php` took 6.4.2 to 7.1.4 in 15 s, database included. A rebuild would then put the release's older code on the newer database. New versions come through this recipe, so someone has to bump it for each security release.
- **`WP_HOME` and `WP_SITEURL` from `HOP3_PUBLIC_URL`.** The golden recipe takes them from the request's `Host`, so a forged header ends up in the page's links, and the installer, with no request, stores `http:` as the site's URL.

The name also avoids a clash with `software/wordpress` in SlapOS, the release upstream maintains.
