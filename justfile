ui_vite_dev:
    cd ui && npm run dev

# Watch all Gleam projects and rebuild all on any change
gleam_build_watch:
    #!/usr/bin/env bash
    set -euxo pipefail

    fswatch ui/src ui/test ui/gleam.toml \
            server/src server/test server/gleam.toml \
            shared/src shared/test shared/gleam.toml | \
    (while read; do
        (cd shared && gleam build) && \
        (cd server && gleam build) && \
        (cd ui && gleam build)
    done)

fetch_package_download_info:
    #!/usr/bin/env bash
    set -euxo pipefail

    cd server

    gleam run -m server/fetch_packages > ../ui/data/downloads.json
