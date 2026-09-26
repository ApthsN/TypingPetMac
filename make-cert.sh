#!/bin/zsh
# Creates a self-signed code-signing certificate in your login keychain.
# With it, macOS keeps the Accessibility permission when you rebuild the app.
# The private key stays on your Mac (signing/ is git-ignored). Never commit it.
set -e
cd "$(dirname "$0")"

IDENTITY="TypingPet Local Signing"
if security find-identity -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
  echo "'$IDENTITY' already exists in your keychain."
  exit 0
fi

mkdir -p signing
cd signing
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 3650 -nodes \
  -subj "/CN=$IDENTITY" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "basicConstraints=critical,CA:false"
PASS=$(openssl rand -hex 16)
openssl pkcs12 -export -legacy -out tp.p12 -inkey key.pem -in cert.pem -passout pass:"$PASS"
security import tp.p12 -k ~/Library/Keychains/login.keychain-db -P "$PASS" -T /usr/bin/codesign
chmod 600 key.pem tp.p12
echo "Created '$IDENTITY'. To remove it later: Keychain Access → delete '$IDENTITY'."
