#!/bin/sh
# Build for the fenix 9 Pro 47mm.
#   ./build.sh           debug build, bin/lcd.prg
#   ./build.sh run       debug build, then launch it in the simulator
#   ./build.sh release   release build to copy onto the watch, bin/RetroLCD.prg
set -e
cd "$(dirname "$0")"
SDK=$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")
KEY="$HOME/.connectiq/developer_key.der"
mkdir -p bin
if [ "$1" = "release" ]; then
    "$SDK/bin/monkeyc" -f monkey.jungle -d fenix9pro47mm -o bin/RetroLCD.prg -y "$KEY" -r -w
    exit 0
fi
"$SDK/bin/monkeyc" -f monkey.jungle -d fenix9pro47mm -o bin/lcd.prg -y "$KEY" -w
if [ "$1" = "run" ]; then
    "$SDK/bin/connectiq"
    sleep 5
    "$SDK/bin/monkeydo" bin/lcd.prg fenix9pro47mm
fi
