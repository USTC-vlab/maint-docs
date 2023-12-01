#!/bin/sh

LOCALDIR=/opt/vlab/code-server
LOCALVERSION="$(jq -r .version "$LOCALDIR/package.json")"

URL="https://github.com/coder/code-server/releases/latest"
VERSION="$(curl -sI "$URL" | perl -ne '/^location:/ && /v([\d.]*)\s*$/ && print $1')"

if [ "$VERSION" = "$LOCALVERSION" ]; then
  echo "Already up-to-date."
  exit 0
fi

URL="https://github.com/coder/code-server/releases/download/v$VERSION/code-server-$VERSION-linux-amd64.tar.gz"
BASENAME="$(basename -s .tar.gz "$URL")"

set -e
cd /tmp
wget -O "$BASENAME.tar.gz" "$URL"
tar zxf "$BASENAME.tar.gz"
rsync -avAX "$BASENAME"/ "$LOCALDIR"/
rm -rf "$BASENAME" "$BASENAME.tar.gz"
