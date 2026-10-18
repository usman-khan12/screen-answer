#!/bin/bash
# Creates a local code-signing certificate ("ScreenAnswer Local Signing") in your login keychain
# and trusts it for code signing. Every build signed with it has the same identity, so macOS keeps
# Screen Recording permission and Keychain access across updates. Safe to run more than once.
set -euo pipefail

NAME="ScreenAnswer Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning | grep -q "\"$NAME\""; then
  echo "Signing certificate already set up."
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if ! security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
  echo "Creating signing certificate…"
  cat > "$TMP/cert.cnf" <<EOF
[req]
distinguished_name=dn
x509_extensions=ext
prompt=no
[dn]
CN=$NAME
[ext]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
EOF
  # Use macOS's built-in openssl: its .p12 files are ones the Keychain can import.
  /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cert.cnf" 2>/dev/null
  P12_PASS=$(/usr/bin/openssl rand -hex 16)
  /usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/id.p12" -passout "pass:$P12_PASS"
  security import "$TMP/id.p12" -k "$KEYCHAIN" -P "$P12_PASS" -T /usr/bin/codesign >/dev/null
else
  security find-certificate -c "$NAME" -p "$KEYCHAIN" > "$TMP/cert.pem"
fi

echo
echo "macOS will now ask for your Mac password to trust this certificate for signing apps."
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem"

if security find-identity -v -p codesigning | grep -q "\"$NAME\""; then
  echo "Signing certificate ready."
  echo "If a dialog asks to let codesign use this key, enter your Mac password and click Always Allow."
else
  echo "Couldn't set up the signing certificate; falling back to basic signing." >&2
  exit 1
fi
