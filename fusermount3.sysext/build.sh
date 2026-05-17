#!/bin/ash
#
# Build script helper for the fusermount3 sysext.
# Runs inside an ephemeral Alpine container; builds a static fusermount3
# from upstream libfuse sources and exports it to a bind-mounted volume.
#
set -euo pipefail

version="$1"
export_user_group="$2"

apk --no-cache add \
  build-base \
  meson \
  ninja \
  pkgconf \
  linux-headers \
  curl \
  tar

cd /opt
curl -fsSL -o libfuse.tar.gz \
  "https://github.com/libfuse/libfuse/releases/download/fuse-${version}/fuse-${version}.tar.gz"
tar -xf libfuse.tar.gz
cd "fuse-${version}"

# Disable examples + tests; we only need the setuid helper. Static link so
# the resulting binary has zero runtime dependencies and survives whatever
# libc the underlying Flatcar release happens to ship.
export CFLAGS='-static -Os'
export LDFLAGS='-static'
meson setup build \
  --prefix=/usr \
  --buildtype=release \
  --default-library=static \
  -Dexamples=false \
  -Dtests=false \
  -Duseroot=false \
  -Dc_link_args='-static'

ninja -C build util/fusermount3

# Install only the binary; no libfuse, no manpages, no udev rules.
install -d /install_root/usr/bin
install -m 4755 -o 0 -g 0 \
  build/util/fusermount3 \
  /install_root/usr/bin/fusermount3

# Restore ownership of the bind-mounted tree to the invoking user so the host
# sysext bakery can package it; preserve the setuid bit + root owner on the
# binary itself (mksquashfs records the uid/gid we set above).
chown -R "$export_user_group" /install_root
chown 0:0 /install_root/usr/bin/fusermount3
chmod 4755 /install_root/usr/bin/fusermount3
