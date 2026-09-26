#!/bin/zsh
# Builds "Typing Pet.app" from TypingPet.swift + images/ and installs it to ~/Applications.
set -e
cd "$(dirname "$0")"

for name in basic Left Right; do
  if [[ ! -f "images/$name.png" ]]; then
    echo "Missing images/$name.png — see images/README.md" >&2
    exit 1
  fi
done

APP="build/Typing Pet.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/images"

swiftc -O -o "$APP/Contents/MacOS/TypingPet" TypingPet.swift -framework Cocoa
cp images/*.png "$APP/Contents/Resources/images/"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Typing Pet</string>
  <key>CFBundleDisplayName</key><string>Typing Pet</string>
  <key>CFBundleIdentifier</key><string>local.typingpet.mac</string>
  <key>CFBundleExecutable</key><string>TypingPet</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Sign with the stable local certificate if it exists (created by make-cert.sh),
# so the Accessibility permission survives rebuilds. Otherwise fall back to ad-hoc.
IDENTITY="TypingPet Local Signing"
if security find-identity -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
  codesign --force --deep --sign "$IDENTITY" "$APP"
else
  echo "Note: '$IDENTITY' not found — signing ad-hoc. Run ./make-cert.sh to keep permissions across rebuilds."
  codesign --force --deep --sign - "$APP"
fi

mkdir -p ~/Applications
rm -rf ~/Applications/"Typing Pet.app"
cp -R "$APP" ~/Applications/
echo "Installed: ~/Applications/Typing Pet.app"
