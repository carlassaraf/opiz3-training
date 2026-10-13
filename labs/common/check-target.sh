#!/bin/sh
# labs/common/check-target.sh — run on the board, paste output to evidence/
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILED=1; }

grep -q "OrangePi Zero3" /proc/device-tree/model && pass "DT model" || fail "DT model"
uname -r | grep -q '^6\.6\.' && pass "kernel 6.6" || fail "kernel version"
[ "$(uname -m)" = "aarch64" ] && pass "aarch64" || fail "arch"
mount | grep -q ' / ' && pass "rootfs mounted" || fail "rootfs"
[ -e /dev/i2c-3 ] && pass "i2c-3 present" || echo "SKIP: i2c-3 (before M10)"
exit ${FAILED:-0}
