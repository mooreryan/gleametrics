ui_gleam_build_watch:
    #!/usr/bin/env bash
    set -euxo pipefail

    cd ui

    fswatch src test gleam.toml | (while read; do gleam build; done)

ui_vite_dev:
    cd ui && npm run dev
