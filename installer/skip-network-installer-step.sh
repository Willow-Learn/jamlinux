#!/bin/sh
set -eu

echo "[jamlinux installer] skipping network installer component: $0" >/dev/tty1 2>/dev/null || true
exit 0
