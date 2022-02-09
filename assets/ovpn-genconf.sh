#!/bin/bash

[ -n "$BASH_VERSION" ] || exit 1
cd "$(dirname "$0")"
PKI="$(dirname "$0")"/pki
OUTDIR="$(dirname "$0")"/clients

gen_conf() {
  local cafile="$1"
  local certfile="$2"
  local keyfile="$3"
  cat << EOF
#!/usr/bin/openvpn
client

proto udp

dev vlabvpn
dev-type tun

persist-key
persist-tun

nobind
remote vpn.ibuglab.com
cipher AES-256-GCM

<ca>
$(<"$cafile")
</ca>
<cert>
$(<"$certfile")
</cert>
<key>
$(<"$keyfile")
</key>
EOF
}

if [ $# -eq 0 ]; then
  echo "Need an argument!" >&2
  exit 1
elif [ $# -gt 1 ]; then
  echo "Too many arguments!" >&2
  exit 1
fi
CN="$1"
OUTFILE="$OUTDIR"/"$CN".ovpn
if [ -f "$OUTFILE" ]; then
  echo "Error: Output file $OUTFILE already exists. Remove it if you want to proceed." >&2
  exit 1
fi

rm -f "$PKI"/reqs/"$CN".req "$PKI"/issued/"$CN".crt "$PKI"/private/"$CN".key
./easyrsa build-client-full "$CN" nopass
gen_conf "$PKI"/ca.crt "$PKI"/issued/"$CN".crt "$PKI"/private/"$CN".key > "$OUTFILE"
rm -f "$PKI"/reqs/"$CN".req "$PKI"/issued/"$CN".crt "$PKI"/private/"$CN".key
