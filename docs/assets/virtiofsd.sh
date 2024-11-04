#!/bin/sh

if test $# -ne 2; then
  echo "Need exactly 2 arguments" >&2
  exit 1
fi

VMID="$1"
PHASE="$2"

if [ "$VMID" -lt 1000 ]; then
  exit 0
fi

case "$PHASE" in
  pre-start) systemctl restart "virtiofsd@$VMID".service ;;
  pre-stop) ;;
  post-start) ;;
  post-stop) ;;
  *) echo "Unknown phase $PHASE" >&2; exit 1;;
esac
