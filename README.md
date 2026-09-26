# 🐾 Typing Pet for Mac

**by [@ApthsN](https://github.com/ApthsN)** · [MIT License](LICENSE)

A tiny macOS desktop pet that reacts when you type: it raises its left and right hands in turn, bounces, and shows special images for chosen keys.

Inspired by [swoonqx/TypingPet](https://github.com/swoonqx/TypingPet) (Windows only). This is an independent Swift app for macOS, not a port of its code.

## Features

- Alternates left/right hand images on every key press, with a small bounce
- Special images for **Space**, **T** and **1** (physical keys, so they work with any keyboard layout, e.g. Thai)
- Always on top, draggable, remembers its position
- Menu bar icon 🐾: size, lock position (click-through), reset position, show/hide, quit
- Shows whether keyboard access is on (🐾 = on, 🐾⚠️ = off)
- Key presses are only used to switch images; nothing is stored or sent, and the app never goes online

## Requirements

- macOS 12 or later
- Xcode Command Line Tools (`xcode-select --install`) for `swiftc`

## Setup

```sh
git clone <this repo>
cd TypingPetMac

# 1. Add your images (see images/README.md)
cp /path/to/your/basic.png /path/to/your/Left.png /path/to/your/Right.png images/

# 2. (Recommended) create a local signing certificate so the permission survives rebuilds
./make-cert.sh

# 3. Build and install to ~/Applications
./build.sh

# 4. Run
open ~/Applications/"Typing Pet.app"
```

### Allow keyboard access

macOS asks for permission the first time. Turn **Typing Pet** on in
**System Settings → Privacy & Security → Accessibility**. The 🐾 icon changes from 🐾⚠️ to 🐾 when it works.

If it doesn't react after a rebuild, remove Typing Pet from that list (−), add it again (+), and switch it on.
Running `./make-cert.sh` once prevents this.

### Start at login (optional)

```sh
cat > ~/Library/LaunchAgents/local.typingpet.mac.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>local.typingpet.mac</string>
  <key>ProgramArguments</key>
  <array><string>/usr/bin/open</string><string>$HOME/Applications/Typing Pet.app</string></array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
EOF
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.typingpet.mac.plist
```

To stop starting at login: turn it off in **System Settings → General → Login Items**, or delete that plist.

## Customising keys

Special keys are set in `TypingPet.swift`:

```swift
private var patterns: [UInt16: String] = [kKeySpace: "space", kKeyT: "T", kKey1: "1"]
```

Map a macOS key code to an image name in `images/`, then run `./build.sh`.

## Troubleshooting

A small log (keyboard-access status and a count of key presses, never which keys) is written to
`~/Library/Logs/TypingPet.log`.

## Credits

- **Typing Pet for Mac** by [Aparpat Hattaphasu (@ApthsN)](https://github.com/ApthsN)
- Inspired by [TypingPet](https://github.com/swoonqx/TypingPet) for Windows by [@swoonqx](https://github.com/swoonqx)

If you use, modify or share this project, please keep the `LICENSE` file and credit:

> Typing Pet for Mac by @ApthsN — https://github.com/ApthsN/TypingPetMac

Character images are not part of this project and belong to their own artists.

## License

[MIT](LICENSE) © 2026 Aparpat Hattaphasu (@ApthsN)
