#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Extension creation script for the fusermount3 sysext.
#
# Ships a statically linked /usr/bin/fusermount3 (built against musl from the
# upstream libfuse sources) so Flatcar nodes have the setuid helper that
# sysbox-fs (and any other host-side FUSE consumer) requires.
#

RELOAD_SERVICES_ON_MERGE="false"

# libfuse upstream tags releases as "fuse-3.16.2"; we accept either the bare
# version (3.16.2) or the prefixed form via the helper below.
function list_available_versions() {
  # libfuse historically tagged fuse2 releases as "fuse_2_9_5" etc.; we only
  # want the modern "fuse-3.x.y" series whose stripped form is a semver.
  list_github_releases "libfuse" "libfuse" \
    | grep -E '^fuse-3\.' \
    | sed 's/^fuse-//'
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local img_arch
  img_arch="$(arch_transform 'x86-64' 'amd64' "$arch")"
  img_arch="$(arch_transform 'arm64' 'arm64/v8' "$img_arch")"

  local image="docker.io/alpine:3.21"

  announce "Building fusermount3 ${version} for ${arch}"

  local user_group
  user_group="$(id -u):$(id -g)"

  cp "${scriptroot}/fusermount3.sysext/build.sh" .
  docker run --rm \
    -i \
    -v "$(pwd)":/install_root \
    --platform "linux/${img_arch}" \
    "${image}" \
      /install_root/build.sh "${version}" "${user_group}"

  cp -aR usr "${sysextroot}/"
}
# --
