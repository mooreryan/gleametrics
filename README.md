# Gleametrics

Package download metrics for Gleam.

## Building

- The ./ui/scripts/build.sh script is for building the app on Cloudflare.
- The `fetch_package_download_info` just recipe is for building the data json file. Would be nice to automate the running of this!
  - Also note that the ui.gleam has a hardcoded fetched at date, so you need to update this as well when updating the data.
  - I have no memory of why I did this, but it should probably not be hardcoded ¯\_(ツ)\_/¯
