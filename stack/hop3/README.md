# hop3: a Hop3 recipe as a SlapOS software release

A [Hop3](https://hop3.cloud) catalog app is a recipe: a `hop3.toml` and a few files (scripts, a pinned `requirements.txt`) whose build commands fetch the app and whose scripts configure it. This stack runs such a recipe on SlapOS as Hop3 would, on the python-app stack (`../python-app/README.md`), and `hox port` (hox-cli) writes an app's `software.cfg` from its recipe:

```
hox port ~/projects/hop3/hop3-catalog/apps/golden/radicale .   # from this checkout's root
```

`software/<app>/` then holds the generated `software.cfg` and `versions.cfg`, and the recipe's files, verbatim, in `hop3/`. Change the recipe and port it again rather than edit them.

## From Hop3 to SlapOS

| Hop3 | Here |
|---|---|
| The recipe's directory, the app's `src/` | `[hop3] files`, fetched next to `software.cfg` into the release (`parts/python-app-git`) |
| `[build] before-build`, `build`, `after-build` | `[hop3] commands`, run there at build time, with `hop3-fetch`, bash (also as `sh`), curl, tar, unzip, make, gzip, grep, gawk, sed, findutils, git and coreutils on `PATH` |
| The Python toolchain's `pip install -r requirements.txt` | the requirements as eggs, pinned in `versions.cfg`; a `python` (and `python3`) with them, and their console scripts on `PATH` |
| Its `pip install .`, without a `requirements.txt` | a develop egg of the tree, after the commands; `hox port --source` pins its dependencies, resolved with uv from an unpacked copy of the release |
| `npm`, `npx` or `node` in the build commands | Node, on `PATH` (`[hop3] tools`) |
| A Go app, found by its `go.mod` with `hox port --source` | SlapOS's Go, built from source, on `PATH`; no eggs and no `versions.cfg`; `GOTOOLCHAIN=local`, so that Go doesn't fetch a binary toolchain |
| `src/` replaced at each deploy, `[[volumes]]` linked into it | the processes run from a copy of the build, made again when it changes, with the volumes linked into it (`copy`, `volumes`) |
| nginx in front of `$BIND_ADDRESS:$PORT` | `bind = ipv4`, a haproxy from the partition's IPv6 |
| The Node toolchain | Node on `PATH`; `npm` compiles native modules from source (`npm_config_build_from_source`, with the headers of SlapOS's Node) |
| The PHP toolchain: php-fpm behind nginx | `php.cfg`, listed after this stack, with its components before: the `fpm` and `web` processes, on `component/apache-php` at PHP 8.3 (the PHP of a Hop3 host on Ubuntu 24.04), with PostgreSQL and SQLite; `PHPRC` for `php` and php-fpm |
| `[proxy] deny`, for a PHP app | `HOP3_PROXY_DENY`: those paths answer 404, as hidden files do |
| `[run] before-run` | the `release` process |
| `[admin] create`, run once after the app starts | the `after-start` process |
| `[run] start`, `[run.workers]` | `web`, and a service each |
| `[env]` literals, references to the domain, `[env.computed]` | `environment` lines |
| `[env]` generated secrets, the `[admin]` password | `secrets`: `NAME:hex`, `NAME:base64`, `NAME:urlsafe` from 32 bytes, as Hop3's defaults; passwords of 32 characters |
| A multi-line or `${…}` `[admin] create` | `hop3-admin-create.sh`, its text as is, next to the recipe's files |
| `[admin] email = "operator"` | `admin@<app>.invalid`, unless `HOP3_ADMIN_EMAIL` is an instance parameter |
| `HOP3_ADMIN_USER`, `HOST_NAME`, `HOP3_PUBLIC_URL` | `environment` lines; `HOP3_ADMIN_EMAIL`, for `email = "operator"`, is an instance parameter |
| `[[addons]] postgres` | PostgreSQL in the partition, `DATABASE_URL` and the `PG*` variables |
| `hop3 config set` | instance parameters |
| `[healthcheck] path` | `health`: promises on the backend and the frontend |

`toolchain = "generic"`, a recipe that fetches a prebuilt binary, is ported as it is, with a note and a comment in `software.cfg`: provisional, since a SlapOS release builds from source. The end state is a port of a variant of the recipe that builds the app.

Not mapped yet: other toolchains, other builders (Docker, Nix), `composer` (not on `PATH`, so a recipe's `composer install … || true` does nothing), `[build] document-root`, the MySQL, Redis, S3 and email addons, `[probe]`, `[[ports]]`, `[access]`, `[waf]`, and `[build]`/`[run]` `packages`. `hox port` lists what a recipe has that it leaves out, and refuses what it can't build.
