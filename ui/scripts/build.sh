#!/usr/bin/env bash
set -euxo pipefail

curl -fsSL https://github.com/gleam-lang/gleam/releases/download/v1.14.0/gleam-v1.14.0-x86_64-unknown-linux-musl.tar.gz | tar -xz

export PATH=$PWD:$PATH

npm install
gleam build --target javascript
npm run build
