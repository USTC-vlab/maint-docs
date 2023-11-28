#!/bin/sh

URL="https://github.com/coder/code-server/releases/latest"
VERSION="$(curl -sI "$URL" | perl -ne '/^location:/ && /v([\d.]*)\s*$/ && print $1')"

URL="https://github.com/coder/code-server/releases/download/v$VERSION/code-server-$VERSION-linux-amd64.tar.gz"
BASENAME="$(basename -s .tar.gz "$URL")"

set -e
cd /tmp
wget -O "$BASENAME.tar.gz" "$URL"
tar zxf "$BASENAME.tar.gz"
rsync -avAX "$BASENAME"/ /opt/vlab/code-server/
rm -rf "$BASENAME" "$BASENAME.tar.gz"
