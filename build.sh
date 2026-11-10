#!/bin/zsh
# 編譯並安裝「混打注音」到 ~/Library/Input Methods
set -e
cd "$(dirname "$0")"
APP="build/MixedIME.app"
DEST="$HOME/Library/Input Methods"

mkdir -p Resources
[ -f vendor/phrase.occ ] && [ -f vendor/en_50k.txt ] || ./tools/fetch_data.sh
[ -f Resources/zh.txt ] || python3 tools/build_data.py
[ -f Resources/icon.tiff ] || swift tools/make_icon.swift Resources/icon.tiff

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O Sources/Engine.swift Sources/App/*.swift -o "$APP/Contents/MacOS/MixedIME"
cp Info.plist "$APP/Contents/"
cp Resources/zh.txt Resources/en.txt Resources/icon.tiff "$APP/Contents/Resources/"
codesign --force --sign - "$APP"

if [ "$1" = "install" ]; then
    pkill -x MixedIME || true
    mkdir -p "$DEST"
    rm -rf "$DEST/MixedIME.app"
    cp -R "$APP" "$DEST/"
    "$DEST/MixedIME.app/Contents/MacOS/MixedIME" --register
    echo "已安裝到 $DEST/MixedIME.app"
fi
