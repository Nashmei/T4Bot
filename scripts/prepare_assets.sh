#!/bin/bash
set -euo pipefail

ICON_DIR="T4Bot/Assets.xcassets/AppIcon.appiconset"
SOURCE="$ICON_DIR/AppIcon.png"
test -s "$SOURCE"

make_icon() {
  local px="$1" out="$2"
  /usr/bin/sips -z "$px" "$px" "$SOURCE" --out "$ICON_DIR/$out" >/dev/null
}

make_icon 40  "Icon-20@2x.png"
make_icon 60  "Icon-20@3x.png"
make_icon 58  "Icon-29@2x.png"
make_icon 87  "Icon-29@3x.png"
make_icon 80  "Icon-40@2x.png"
make_icon 120 "Icon-40@3x.png"
make_icon 120 "Icon-60@2x.png"
make_icon 180 "Icon-60@3x.png"

cat > "$ICON_DIR/Contents.json" <<'JSON'
{
  "images": [
    {"filename":"Icon-20@2x.png","idiom":"iphone","scale":"2x","size":"20x20"},
    {"filename":"Icon-20@3x.png","idiom":"iphone","scale":"3x","size":"20x20"},
    {"filename":"Icon-29@2x.png","idiom":"iphone","scale":"2x","size":"29x29"},
    {"filename":"Icon-29@3x.png","idiom":"iphone","scale":"3x","size":"29x29"},
    {"filename":"Icon-40@2x.png","idiom":"iphone","scale":"2x","size":"40x40"},
    {"filename":"Icon-40@3x.png","idiom":"iphone","scale":"3x","size":"40x40"},
    {"filename":"Icon-60@2x.png","idiom":"iphone","scale":"2x","size":"60x60"},
    {"filename":"Icon-60@3x.png","idiom":"iphone","scale":"3x","size":"60x60"},
    {"filename":"AppIcon.png","idiom":"ios-marketing","scale":"1x","size":"1024x1024"}
  ],
  "info": {"author":"xcode","version":1}
}
JSON
