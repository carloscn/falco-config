#!/bin/sh
# Start Falco in background (use this if systemd is not available on board).
# Logs go to /var/log/falco.log

FALCO=/usr/local/bin/falco
CONFIG=/etc/falco/falco.yaml
LOG=/var/log/falco.log

if [ ! -x "$FALCO" ]; then
    echo "Falco not found: $FALCO"
    exit 1
fi

# Kill existing falco process
pkill -x falco 2>/dev/null || true
sleep 1

# Unload any existing falco/scap kernel module so we load the one we deployed (avoids PPM_IOCTL_GET_API_VERSION mismatch)
rmmod falco 2>/dev/null || true
rmmod scap 2>/dev/null || true
sleep 1

# Load our falco.ko (must match the Falco binary from the same build). Prefer deployed path.
if [ -f /usr/share/falco/falco.ko ]; then
    insmod /usr/share/falco/falco.ko 2>/dev/null && echo "Loaded /usr/share/falco/falco.ko" || true
elif [ -f "/lib/modules/$(uname -r)/extra/falco.ko" ]; then
    insmod "/lib/modules/$(uname -r)/extra/falco.ko" 2>/dev/null && echo "Loaded extra/falco.ko" || true
elif [ -f /opt/falco-test/falco.ko ]; then
    insmod /opt/falco-test/falco.ko 2>/dev/null && echo "Loaded /opt/falco-test/falco.ko" || true
fi

echo "Starting Falco in background, log: $LOG"
nohup "$FALCO" -c "$CONFIG" >> "$LOG" 2>&1 &
sleep 1

if pgrep -x falco >/dev/null; then
    echo "Falco started (PID $(pgrep -x falco))"
else
    echo "Falco may have failed. Check: tail $LOG"
    exit 1
fi
