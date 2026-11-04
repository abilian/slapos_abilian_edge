# Mattermost, built from source

The same app and configuration as the native `mattermost` entry, which runs the release Mattermost publishes. This variant builds the server, `mmctl` and the web client from the tagged source, with Go and Node.

What differs from the published release:

- Node: the source asks for Node 18, and this builds with a newer one, relaxing that check.
- Prepackaged plugins: left out. The published release bundles them as signed downloads, which aren't built from this source.
- Web client: no source maps, for the build's memory, and images aren't compressed, which would run prebuilt binaries.
- License: the published binary is under MIT, and a binary compiled from this source is under AGPL-3.0.

What the build still takes as it comes:

- Go modules, fetched at build time and checked against `go.sum`.
- npm packages, fetched at build time and checked against `package-lock.json`.

Mattermost publishes no source release, so the sha256 is taken from the tag's archive.

Alpha: it has not been through `hop3-test`.
