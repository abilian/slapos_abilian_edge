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
| `[build] before-build`, `build`, `after-build` | `[hop3] commands`, run there at build time, with `hop3-fetch`, bash (also as `sh`), curl, tar, gzip, grep, sed, findutils and coreutils on `PATH` |
| The Python toolchain's `pip install -r requirements.txt` | the requirements as eggs, pinned in `versions.cfg`; a `python` (and `python3`) with them, and their console scripts on `PATH` |
| Its `pip install .`, without a `requirements.txt` | a develop egg of the tree, after the commands; `hox port --source` pins its dependencies, resolved with uv from an unpacked copy of the release |
| `npm`, `npx` or `node` in the build commands | Node, on `PATH` (`[hop3] tools`) |
| `src/` replaced at each deploy, `[[volumes]]` linked into it | the processes run from a copy of the build, made again when it changes, with the volumes linked into it (`copy`, `volumes`) |
| nginx in front of `$BIND_ADDRESS:$PORT` | `bind = ipv4`, a haproxy from the partition's IPv6 |
| `[run] before-run`, `[admin] create` | the `release` process |
| `[run] start`, `[run.workers]` | `web`, and a service each |
| `[env]` literals, references to the domain, `[env.computed]` | `environment` lines |
| `[env]` generated secrets, the `[admin]` password | `secrets` (32-character passwords, whatever the generator) |
| `HOP3_ADMIN_USER`, `HOST_NAME`, `HOP3_PUBLIC_URL` | `environment` lines; `HOP3_ADMIN_EMAIL`, for `email = "operator"`, is an instance parameter |
| `[[addons]] postgres` | PostgreSQL in the partition, `DATABASE_URL` and the `PG*` variables |
| `hop3 config set` | instance parameters |
| `[healthcheck] path` | `health`: promises on the backend and the frontend |

Not mapped yet: other toolchains (Go and PHP binaries, Node), other builders (Docker, Nix), the MySQL, Redis, S3 and email addons, `[probe]`, `[[ports]]`, `[access]`, `[waf]`, and `[build]`/`[run]` `packages`. `hox port` lists what a recipe has that it leaves out, and refuses what it can't build.
