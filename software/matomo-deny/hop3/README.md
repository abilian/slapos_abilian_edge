# Matomo, current, with its `.htaccess` rules as a deny list

The golden recipe, with three changes:

- **`[proxy] deny`.** nginx ignores the `.htaccess` files Matomo generates. The list covers those directories and the recipe's own files.
- **Matomo 5.14.2, checked by sha256**, in place of 5.0.1.
- **`install.php` loads and installs the plugins before it adds the first site.** 5.14 checks the site's type against them and reads their tables, and the install fails otherwise.

The name also avoids a clash with `software/matomo` in SlapOS, the release upstream maintains.
