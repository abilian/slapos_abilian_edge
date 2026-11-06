# python-app: a Python web app as a SlapOS software release

Builds a Python app from its git repository and runs it as Procfile-style processes, behind Rapid.Space's shared frontend, with PostgreSQL if it needs one. An app's `software.cfg` is then only what is its own: see `software/mynij-proxy/` (an ASGI app, nothing else) and `software/aipress24/` (Flask, PostgreSQL, WeasyPrint, a worker and a scheduler).

## An app's software.cfg

```ini
[buildout]
# Components first (some set [buildout] parts, and `parts +=` must add to the
# stack's), then the stack, then the app's pins.
extends =
  ../../component/postgresql/buildout.cfg
  ../../stack/python-app/buildout.cfg
  ./versions.cfg
parts +=
  postgresql

[python3]
<= python3.13

[python-app]
name = myapp
repository = https://github.com/me/myapp.git
branch = main
egg = myapp
eggs = gunicorn
scripts = gunicorn
health = /health
postgresql-bin = ${postgresql:location}/bin

[python-app-processes]
web = gunicorn -b "[$HOST]:$PORT" "myapp:create_app()"
release = flask db upgrade
```

`versions.cfg` comes from the app's `uv.lock`: `hox versions uv.lock --python 3.13` (hox-cli).

## [python-app]

At build time:

| Option | |
|---|---|
| `name` | Names the database, its user and the frontend request. |
| `repository`, `branch`, `revision` | The app's git checkout. A `revision` pins a commit. |
| `egg` | The app's distribution, installed as a develop egg from the checkout. |
| `setup-eggs` | Its build backend, when it isn't setuptools (`pdm-backend`, `hatchling`). |
| `eggs`, `scripts` | More eggs, and the scripts to generate. zc.recipe.egg makes scripts only for the eggs listed in its part, not for their dependencies: an egg whose command a process runs (`gunicorn`, `flask`) goes in both. |
| `source` | The checkout's directory with the app's packages (`src`), put on the scripts' `sys.path`: an editable install is a `.pth` file, which buildout's scripts don't read. |

At instance time:

| Option | |
|---|---|
| `port` | The port `web` listens on (8080). |
| `health` | A path that answers 200 when the app is up (`/health`): checked on the backend and through the frontend, by promises. |
| `environment` | Shell lines exported to every process, after the stack's variables: the app's own names for them (`FLASK_SERVER_NAME=$DOMAIN`). |
| `secrets` | Variable names, each given a random value generated once and kept: `SECRET_KEY`. `NAME:hex`, `NAME:base64` or `NAME:urlsafe` for 32 random bytes in that encoding. |
| `postgresql-bin` | `${postgresql:location}/bin`, for a database. |
| `mariadb-bin` | `${mariadb:location}/bin`, for a MariaDB database in the partition. |
| `path`, `library-path` | More directories for `PATH` and `LD_LIBRARY_PATH` (the libraries the app loads at run time). |
| `fonts`, `fontconfig-includes`, `fonts-conf` | Font directories and fontconfig's, for a `FONTCONFIG_FILE`. |
| `copy`, `build-id`, `volumes` | For an app that writes next to its code: with `copy = true` the processes run from a copy of the build in `srv/app`, made again when `build-id` changes. `volumes` are `name target` lines: directories kept in `srv/volumes/<name>`, outside the copy, and linked at `target` in it; an empty one is first filled with what the build left at `target`. |
| `bind` | `ipv6` (the default): `web` listens on `[$HOST]:$PORT`. `ipv4`: it listens on `$BIND_ADDRESS:$PORT` (or `0.0.0.0`), with `BIND_ADDRESS` 127.0.0.1 and a port of its own (30000 + the partition's number), and a haproxy on 20000 + that number brings the frontend's IPv6 to it: a separate number, since a Go app's `:$PORT` or `0.0.0.0:$PORT` also takes the IPv6 wildcard. As behind Hop3's nginx, the requests come from 127.0.0.1, whose `X-Forwarded-Proto` gunicorn trusts by default. |

## [python-app-processes]

One option per process, `name = command`, as a Procfile line: a shell runs it from the checkout (or its copy), with the environment below, and once the database answers if there is one. Each is a service (restarted by supervisord), except `release`, which runs once at each start (migrations, seeding: it must be idempotent). It waits for the frontend's URL, as release scripts write that into configuration, and the services wait for it to succeed with the current parameters, build and URL. An app with a `release` therefore starts once the frontend is published. `after-start` is also not a service: it runs alongside them, for what needs the running app (an admin account in the tables `web` creates). It is tried again until it succeeds, then never again in this partition: a marker in `srv` keeps a deleted account from coming back. `web` must listen on `[$HOST]:$PORT`. A command is one line; write `$VAR`, not `${VAR}` (buildout would read it).

## What a process gets

| Variable | |
|---|---|
| `HOST`, `PORT` | Where `web` listens: the partition's IPv6, `[python-app] port`; with `bind = ipv4`, 127.0.0.1 and a port of its own. |
| `BIND_ADDRESS` | With `bind = ipv4`: `HOST`, as Hop3 names it. |
| `URL`, `DOMAIN` | The frontend's URL and domain, once the frontend is allocated. |
| `DATABASE_URL`, `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE`, `PGSSLMODE` | `postgresql://user:password@host:port/name`, and its parts as libpq names them (`PGSSLMODE=disable`: the partition's PostgreSQL has no TLS, and some drivers require it by default), with `postgresql-bin`. |
| `DATABASE_URL`, `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_DATABASE` | With `mariadb-bin`: `mysql://user:password@host:port/name`, and its parts as Hop3's addon names them. |
| `HOME`, `TMPDIR`, `LANG` | In the partition; `C.UTF-8`. |
| `PATH` | The release's `bin/` (scripts, `app-python`), git, coreutils, PostgreSQL's tools, `[python-app] path`. Nothing else: services start with an empty environment. |
| each of `secrets` | Its generated value. |
| each instance parameter | Under its own name, last: a parameter overrides everything (as `hop3 config set`). |

The release is read-only for the partition: an app writes under `HOME` or `TMPDIR`, never next to its code. A change of command, environment or parameters gives new wrappers (`hash-files`), so supervisord restarts the processes.

## A venv in place of buildout's eggs

Buildout installs eggs with SlapOS's pip and setuptools, and without an index, which many recent sdists can't build with. `venv.cfg` installs the app in a venv of its own instead, created from SlapOS's Python, with the pip that Python bundles. Compiled packages are built from their sdists, and pure ones stay wheels.

```ini
[buildout]
extends =
  ../../component/libffi/buildout.cfg
  ../../stack/python-app/buildout.cfg
  ../../stack/python-app/venv.cfg

[python-app-requirements]
url = ${:_profile_base_location_}/requirements.txt
md5sum = …

[python-app]
no-binary = cffi markupsafe
build-libraries = ${libffi:location}
uploaded-prior-to = 2026-11-04T12:00:00Z
```

`requirements.txt` holds the pins with their hashes (`uv pip compile --generate-hashes`). `hox port --venv` writes all of this for a Hop3 recipe, which also extends `stack/hop3/venv.cfg` last.

The build needs PyPI, and SlapOS's network cache doesn't cover these packages, so a new node builds them again. `eggs`, `scripts`, `setup-eggs` and `source` don't apply. `egg` installs the checkout into the venv. The commands stay on the processes' `PATH`, with `app-python` as the venv's Python.
