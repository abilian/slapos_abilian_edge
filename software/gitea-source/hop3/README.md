# Gitea, built from source

The same app and configuration as the native `gitea` entry, which runs the binary Gitea publishes. This variant builds that binary from Gitea's source release, with Go.

The source release ships its web assets already built, so Node isn't needed here: those assets are the one part this variant doesn't build.

Alpha: it has not been through `hop3-test`.
