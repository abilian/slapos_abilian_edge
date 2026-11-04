# Vikunja, built from source

The same app and configuration as the native `vikunja` entry, which runs the binary Vikunja publishes. This variant builds the binary and its frontend from the tagged source, with Go and Node.

What the build still takes as it comes:

- Go modules, fetched at build time and checked against `go.sum`.
- npm packages, fetched at build time and checked against `pnpm-lock.yaml`. Some of those are prebuilt native tools (`esbuild`, `rollup`), used for the build only and not run by the app.

Vikunja publishes no source release, so the sha256 is taken from the tag's archive.

Alpha: it has not been through `hop3-test`.
