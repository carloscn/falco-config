#!/bin/sh
# Load falco.ko for Falco (kmod engine). Run before starting Falco, e.g. from systemd ExecStartPre.
# Uses full paths so it works when PATH is minimal (e.g. systemd).
# Deploy to board /opt/falco-test/load-falco-ko.sh; falco.service runs this before starting Falco.

set -e
RMMOD="/sbin/rmmod"
INSMOD="/sbin/insmod"
[ -x "$RMMOD" ] || RMMOD="/usr/sbin/rmmod"
[ -x "$INSMOD" ] || INSMOD="/usr/sbin/insmod"
KO="/usr/share/falco/falco.ko"

# Unload any existing module so we load the one we deployed (avoids PPM_IOCTL_GET_API_VERSION mismatch)
$RMMOD falco 2>/dev/null || true
$RMMOD scap 2>/dev/null || true
sleep 1

if [ ! -f "$KO" ]; then
    echo "load-falco-ko: $KO not found"
    exit 1
fi
$INSMOD "$KO" || exit 1
echo "load-falco-ko: loaded $KO"
