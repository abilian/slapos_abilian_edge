# Forgejo, built from source

The same app and configuration as the native `forgejo` entry, which runs the binary Forgejo publishes. This variant builds that binary from Forgejo's source release, with Go 1.25 or newer.

The source release ships its web assets already built, so Node isn't needed here: those assets are the one part this variant doesn't build.

Alpha: it has not been through `hop3-test`.
