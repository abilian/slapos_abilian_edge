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
| `secrets` | Variable names, each given a random value generated once and kept: `SECRET_KEY`. |
| `postgresql-bin` | `${postgresql:location}/bin`, for a database. |
| `path`, `library-path` | More directories for `PATH` and `LD_LIBRARY_PATH` (the libraries the app loads at run time). |
| `fonts`, `fontconfig-includes`, `fonts-conf` | Font directories and fontconfig's, for a `FONTCONFIG_FILE`. |
| `copy`, `build-id`, `volumes` | For an app that writes next to its code: with `copy = true` the processes run from a copy of the build in `srv/app`, made again when `build-id` changes. `volumes` are `name target` lines: directories kept in `srv/volumes/<name>`, outside the copy, and linked at `target` in it; an empty one is first filled with what the build left at `target`. |
| `bind` | `ipv6` (the default): `web` listens on `[$HOST]:$PORT`. `ipv4`: it listens on `$BIND_ADDRESS:$PORT` (or `0.0.0.0`), with `BIND_ADDRESS` 127.0.0.1 and a port of its own (20000 + the partition's number), and a haproxy brings the frontend's IPv6 to it. As behind Hop3's nginx, the requests come from 127.0.0.1, whose `X-Forwarded-Proto` gunicorn trusts by default. |

## [python-app-processes]

One option per process, `name = command`, as a Procfile line: a shell runs it from the checkout (or its copy), with the environment below, and once the database answers if there is one. Each is a service (restarted by supervisord), except `release`, which runs once at each start (migrations, seeding: it must be idempotent). The services wait for it to succeed with the current parameters and build. `web` must listen on `[$HOST]:$PORT`. A command is one line; write `$VAR`, not `${VAR}` (buildout would read it).

## What a process gets

| Variable | |
|---|---|
| `HOST`, `PORT` | Where `web` listens: the partition's IPv6, `[python-app] port`; with `bind = ipv4`, 127.0.0.1 and a port of its own. |
| `BIND_ADDRESS` | With `bind = ipv4`: `HOST`, as Hop3 names it. |
| `URL`, `DOMAIN` | The frontend's URL and domain, once the frontend is allocated. |
| `DATABASE_URL`, `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE` | `postgresql://user:password@host:port/name`, and its parts as libpq names them, with `postgresql-bin`. |
| `HOME`, `TMPDIR`, `LANG` | In the partition; `C.UTF-8`. |
| `PATH` | The release's `bin/` (scripts, `app-python`), git, coreutils, PostgreSQL's tools, `[python-app] path`. Nothing else: services start with an empty environment. |
| each of `secrets` | Its generated value. |
| each instance parameter | Under its own name, last: a parameter overrides everything (as `hop3 config set`). |

The release is read-only for the partition: an app writes under `HOME` or `TMPDIR`, never next to its code. A change of command, environment or parameters gives new wrappers (`hash-files`), so supervisord restarts the processes.
